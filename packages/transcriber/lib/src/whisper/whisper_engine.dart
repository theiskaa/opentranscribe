import 'dart:async';
import 'dart:io';

import 'package:transcriber/src/audio/audio_activity.dart';
import 'package:transcriber/src/transcribe/install_wait.dart';
import 'package:transcriber/src/transcribe/transcript.dart';
import 'package:transcriber/src/transcribe/transcription_engine.dart';
import 'package:transcriber/src/transcribe/transcription_exception.dart';
import 'package:transcriber/src/whisper/model_fetcher.dart';
import 'package:transcriber/src/whisper/pcm_decoder.dart';
import 'package:transcriber/src/whisper/voiced_segments.dart';
import 'package:transcriber/src/whisper/whisper_catalog.dart';
import 'package:transcriber/src/whisper/whisper_runtime.dart';
import 'package:transcriber/src/whisper/zip_extract.dart';

/// whisper.cpp as a batch-only engine: one downloaded model serves every
/// language it knows, and the per-language questions answer for that model.
/// Every model knows the same ninety-nine; the large-v3 family adds Cantonese.
///
/// Guarantees: the only connection it opens is the [ModelFetcher]'s, for a
/// catalog file. Runs are serialized, hold at most [chunkLength] of decoded
/// audio at a time and delete every scratch file whether they land or fail;
/// [cancelBatches] ends the run in flight, its first-use download included,
/// and drops the queued ones. The service installs a missing model before a
/// run; the engine's own first-use install is the fallback for any other
/// caller. A model counts as installed only at the catalog's length (its hash
/// was checked at install), and the preflights ([installedModels],
/// [localeStatus] and the like) never throw. A run keeps the model chosen
/// when it was queued.
///
/// Acceleration is whisper.cpp's Core ML encoder, unpacked beside the model
/// and compiled by a first load.
///
/// Whisper pads every slice to its 30 s window and fills silence with words
/// nobody said ("Thank you.", "..."), so a run keeps only segments with
/// letters or digits that start inside the slice (and inside the chunk a
/// long slice runs in), their ends clamped to it ([keepVoiced]). With an
/// [AudioActivity], a slice the probe finds silent runs nothing and lands no
/// words, and segments far from any voice go too.
class WhisperEngine
    implements
        TranscriptionEngine,
        ManagedModelEngine,
        CancellableBatchEngine,
        ModelChoiceEngine,
        PacedBatchEngine,
        ReleasableEngine,
        ProgressBatchEngine,
        AcceleratedModelEngine,
        LanguageOddsEngine {
  WhisperEngine({
    required this._modelsDir,
    required this._fetcher,
    required this._decoder,
    required this._runtime,
    this._activity,
    String initialModelId = whisperDefaultModelId,
    this.canAccelerate = false,
    bool initiallyAccelerated = false,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now,
       _accelerated = canAccelerate && initiallyAccelerated {
    _selectedId = _model(initialModelId).id;
  }

  static const String engineId = 'whisper.cpp';
  static const _batchFloor = Duration(minutes: 2);

  /// The most audio a run holds at once: ten minutes of samples plus their
  /// spectrogram fit the catalog's memory figures, whatever the entry's length.
  static const chunkLength = Duration(minutes: 10);

  // A segment ending this close to a chunk's edge may have run past it; one
  // ending earlier finished inside.
  static const _tailMargin = Duration(seconds: 2);
  static const _cancelled = TranscriptionFailed('cancelled');

  final Directory _modelsDir;
  final ModelFetcher _fetcher;
  final PcmDecoder _decoder;
  final WhisperRuntime _runtime;
  final AudioActivity? _activity;
  final DateTime Function() _clock;

  late String _selectedId;
  bool _accelerated;
  WhisperSession? _session;
  String? _sessionModelId;
  Future<void> _closing = Future<void>.value();
  int _releases = 0;
  bool _sweptScratch = false;
  Future<void> _batches = Future<void>.value();
  Future<void> _installs = Future<void>.value();
  // Bumped by cancelBatches; a run queued before the bump never starts.
  int _generation = 0;
  bool _running = false;
  // The model the run in flight is loading or using, whatever the choice
  // moved to since.
  String? _runningModelId;
  // Runs queued or in flight, per model id; a removal would pull the file
  // from beneath one.
  final Map<String, int> _holding = {};
  // A removal in flight, per model id: a run or an install reaching that
  // model meanwhile waits it out, so it finds the file gone, not going.
  final Map<String, Completer<void>> _removals = {};
  // Downloads in flight or waiting their turn, per id; a removal under one
  // would pull the file from beneath the fetcher.
  final Map<String, int> _installing = {};
  Future<void> Function()? _cancelFirstUse;

  @override
  String get id => engineId;

  @override
  bool get onDeviceOnly => true;

  WhisperModel _model(String id) =>
      whisperModelById(id) ?? (throw ArgumentError.value(id, 'id', 'not in the catalog'));

  File _file(WhisperModel model) => File('${_modelsDir.path}/${model.fileName}');

  Future<bool> _installed(WhisperModel model) async {
    final stat = await _file(model).stat();
    return stat.type == FileSystemEntityType.file && stat.size == model.option.bytes;
  }

  Directory _encoderDir(WhisperModel model) =>
      Directory('${_modelsDir.path}/${model.encoderDirName}');

  File _encoderZip(WhisperModel model) => File('${_modelsDir.path}/${model.encoder.fileName}');

  // Unpacked here and renamed into place last, so a present directory is a
  // whole one.
  Directory _encoderStaging(WhisperModel model) =>
      Directory('${_modelsDir.path}/.unpack-${model.encoderDirName}');

  Future<bool> _acceleratedFor(WhisperModel model) => _encoderDir(model).exists();

  Future<void> _deleteEncoder(WhisperModel model) async {
    for (final leftover in [
      _encoderDir(model),
      _encoderStaging(model),
      _encoderZip(model),
      File('${_encoderZip(model).path}$modelPartSuffix'),
    ]) {
      if (await leftover.exists()) await leftover.delete(recursive: true);
    }
  }

  /// The whisper code the selected model can run [localeId] as, or null.
  String? _codeFor(String localeId) {
    final code = whisperLanguageCode(localeId);
    return code != null && _model(_selectedId).speaks(code) ? code : null;
  }

  @override
  Future<Availability> checkAvailability({required String localeId}) async =>
      _codeFor(localeId) == null
      ? Availability(AvailabilityStatus.onDeviceUnavailable, detail: 'unsupported: $localeId')
      : const Availability.available();

  @override
  Future<List<String>> supportedLocales() async => _model(_selectedId).supportedTags;

  @override
  Future<Transcript> transcribeFile(
    File audio, {
    required String localeId,
    Duration? start,
    Duration? end,
  }) => _enqueue(audio, localeId: localeId, start: start, end: end);

  @override
  Future<Transcript> transcribeFileWithProgress(
    File audio, {
    required String localeId,
    required void Function(double fraction) onProgress,
    Duration? start,
    Duration? end,
  }) => _enqueue(audio, localeId: localeId, start: start, end: end, onProgress: onProgress);

  @override
  Future<Map<String, double>> languageOdds(
    File audio, {
    required Duration start,
    required Duration end,
    required List<String> among,
  }) async {
    final model = _model(_selectedId);
    final codes = [
      for (final tag in among) _codeFor(tag) ?? (throw OnDeviceUnavailable('unsupported: $tag')),
    ];
    return _queued(
      model,
      (generation) => _odds(audio, model, among, codes, start, end, generation),
    );
  }

  /// [body] in its turn on the run chain, holding [model] meanwhile; a cancel
  /// before the turn comes shows in the generation it is handed.
  Future<T> _queued<T>(WhisperModel model, Future<T> Function(int generation) body) {
    final generation = _generation;
    _holding[model.id] = (_holding[model.id] ?? 0) + 1;
    final run = _batches.then((_) => body(generation));
    // The chain only sequences; one failure must not poison every later run.
    _batches = run.then((_) {}, onError: (Object _) {});
    return run.whenComplete(() => _decrement(_holding, model.id));
  }

  Future<Map<String, double>> _odds(
    File audio,
    WhisperModel model,
    List<String> among,
    List<String> codes,
    Duration start,
    Duration end,
    int generation,
  ) async {
    if (generation != _generation) throw _cancelled;
    _running = true;
    _runningModelId = model.id;
    try {
      await _removals[model.id]?.future;
      // A question about a stretch never pays for a download.
      if (!await _installed(model)) throw const OnDeviceUnavailable('model not installed');
      if (generation != _generation) throw _cancelled;
      final session = await _sessionFor(model);
      final odds = await _onSlice(
        session,
        audio,
        start: start,
        end: end,
        generation: generation,
        use: (pcm) => session.detect(pcm, codes: codes),
      );
      // A detect cannot be aborted, so a cancel during one shows only here.
      if (generation != _generation) throw _cancelled;
      return {for (final (i, tag) in among.indexed) tag: odds?[i] ?? 0};
    } finally {
      await _runEnded(model);
    }
  }

  Future<Transcript> _enqueue(
    File audio, {
    required String localeId,
    Duration? start,
    Duration? end,
    void Function(double fraction)? onProgress,
  }) async {
    // Fixed at the ask: the language was checked against this model.
    final model = _model(_selectedId);
    final language = _codeFor(localeId);
    if (language == null) throw OnDeviceUnavailable('unsupported: $localeId');
    return _queued(
      model,
      (generation) =>
          _transcribe(audio, model, localeId, language, start, end, generation, onProgress),
    );
  }

  static void _decrement(Map<String, int> counts, String id) {
    final left = (counts[id] ?? 1) - 1;
    if (left <= 0) {
      counts.remove(id);
    } else {
      counts[id] = left;
    }
  }

  Future<Transcript> _transcribe(
    File audio,
    WhisperModel model,
    String localeId,
    String language,
    Duration? start,
    Duration? end,
    int generation,
    void Function(double fraction)? onProgress,
  ) async {
    if (generation != _generation) throw _cancelled;
    _running = true;
    _runningModelId = model.id;
    try {
      await _removals[model.id]?.future;
      if (!await _installed(model)) {
        // A cancel landing while a removal was waited out must not refetch.
        if (generation != _generation) throw _cancelled;
        await _installFirstUse(model);
      }
      if (generation != _generation) throw _cancelled;
      final Duration total;
      try {
        total = await _decoder.length(audio);
      } on PcmDecodeFailed catch (e) {
        throw _decodeFailure(e);
      }
      final from = start ?? Duration.zero;
      final to = end ?? total;
      if (to <= from) return _transcript(const [], localeId);
      final sliceEnd = to < total ? to : total;
      // Before the load: a slice with no voice costs no model.
      final voiced = await _activity?.voiced(audio, start: from, end: sliceEnd);
      if (generation != _generation) throw _cancelled;
      if (voiced != null && voiced.isEmpty) return _transcript(const [], localeId);
      final session = await _sessionFor(model);
      if (generation != _generation) throw _cancelled;
      final List<WhisperSegment> heard;
      if (to - from <= chunkLength) {
        heard =
            await _hear(
              session,
              audio,
              language: language,
              start: start,
              end: end,
              generation: generation,
              onProgress: onProgress,
            ) ??
            const [];
      } else {
        heard = await _hearInChunks(
          session,
          audio,
          language: language,
          from: from,
          to: sliceEnd,
          generation: generation,
          onProgress: onProgress,
        );
      }
      final voicedInSlice = voiced == null
          ? null
          : [for (final range in voiced) (start: range.start - from, end: range.end - from)];
      return _transcript(
        keepVoiced(heard, voiced: voicedInSlice, length: sliceEnd - from),
        localeId,
      );
    } finally {
      await _runEnded(model);
    }
  }

  Future<void> _runEnded(WhisperModel model) async {
    _running = false;
    _runningModelId = null;
    // The encoder a turn-off left for this run goes now; one an install is
    // fetching is that install's to drop.
    if (!_accelerated && !_installing.containsKey(model.id) && await _acceleratedFor(model)) {
      await _closeSession();
      await _deleteEncoder(model);
    }
  }

  /// [from] to [to] of [audio], longer than [chunkLength], heard one chunk at a
  /// time, its segments timed from [from] and its progress one climb.
  Future<List<WhisperSegment>> _hearInChunks(
    WhisperSession session,
    File audio, {
    required String language,
    required Duration from,
    required Duration to,
    required int generation,
    void Function(double fraction)? onProgress,
  }) async {
    final whole = (to - from).inMicroseconds;
    final segments = <WhisperSegment>[];
    var cursor = from;
    // A re-heard tail restarts below the last fraction reported; only a
    // climb is forwarded.
    var reported = 0.0;
    while (cursor < to) {
      final chunkEnd = cursor + chunkLength < to ? cursor + chunkLength : to;
      final length = chunkEnd - cursor;
      final done = (cursor - from).inMicroseconds;
      final heard = await _hear(
        session,
        audio,
        language: language,
        start: cursor,
        end: chunkEnd,
        generation: generation,
        onProgress: onProgress == null
            ? null
            : (p) {
                final fraction = (done + p * length.inMicroseconds) / whole;
                if (fraction <= reported) return;
                reported = fraction;
                onProgress(fraction);
              },
      );
      if (heard == null) break;
      // Past the chunk's end is its padding; the next chunk hears that audio.
      var kept = [
        for (final s in heard)
          if (s.start < length) s,
      ];
      var next = chunkEnd;
      // A last segment running into the boundary may be cut by it; the next
      // chunk starts where it began, so the words are heard whole once.
      final last = kept.lastOrNull;
      if (chunkEnd < to &&
          last != null &&
          last.start > Duration.zero &&
          last.end >= length - _tailMargin) {
        kept = kept.sublist(0, kept.length - 1);
        next = cursor + last.start;
      }
      final offset = cursor - from;
      for (final s in kept) {
        segments.add(
          WhisperSegment(
            text: s.text,
            start: s.start + offset,
            end: s.end + offset,
            confidence: s.confidence,
          ),
        );
      }
      cursor = next;
    }
    return segments;
  }

  /// [_onSlice] running whisper in [language].
  Future<List<WhisperSegment>?> _hear(
    WhisperSession session,
    File audio, {
    required String language,
    required Duration? start,
    required Duration? end,
    required int generation,
    void Function(double fraction)? onProgress,
  }) => _onSlice(
    session,
    audio,
    start: start,
    end: end,
    generation: generation,
    use: (pcm) => session.run(pcm, language: language, onProgress: onProgress),
  );

  /// [use] over one decoded slice, its scratch file deleted after. Null for a
  /// slice holding no audio: past the file's end, or empty.
  Future<T?> _onSlice<T>(
    WhisperSession session,
    File audio, {
    required Duration? start,
    required Duration? end,
    required int generation,
    required Future<T> Function(File pcm) use,
  }) async {
    // Checked before the decode too: a cancel between chunks must not pay
    // for another ten minutes of it.
    if (generation != _generation) throw _cancelled;
    final DecodedPcm decoded;
    try {
      decoded = await _decoder.decode(audio, start: start, end: end);
      if (!_sweptScratch) {
        _sweptScratch = true;
        await _sweepScratch(decoded.file);
      }
    } on PcmDecodeFailed catch (e) {
      if (e.code == PcmDecodeFailed.empty) return null;
      throw _decodeFailure(e);
    }
    try {
      if (generation != _generation) throw _cancelled;
      return await use(decoded.file);
    } on WhisperRuntimeException catch (e) {
      throw switch (e.error) {
        WhisperRuntimeError.aborted => _cancelled,
        _ => TranscriptionFailed('run failed: ${e.message ?? e.error.name}'),
      };
    } on StateError {
      // The session was released under this run; a release that raced the
      // load left it closed, so the next run must load again.
      if (identical(_session, session)) {
        _session = null;
        _sessionModelId = null;
      }
      throw _cancelled;
    } finally {
      await decoded.file.delete().catchError((_) => decoded.file);
    }
  }

  TranscriptionException _decodeFailure(PcmDecodeFailed e) => e.code == PcmDecodeFailed.missing
      ? RecordingMissing(e.message)
      : TranscriptionFailed('decode failed: ${e.message}');

  /// Runs are serialized, so beside the first run's own slice every decoded
  /// file is one a killed process never deleted: a copy of the user's voice.
  Future<void> _sweepScratch(File current) async {
    try {
      await for (final leftover in current.parent.list()) {
        final name = leftover.uri.pathSegments.last;
        if (leftover is File &&
            leftover.path != current.path &&
            name.startsWith('otr-') &&
            name.endsWith('.pcm')) {
          await leftover.delete().catchError((_) => leftover);
        }
      }
    } on FileSystemException {
      // Best effort; the next launch sweeps again.
    }
  }

  Future<void> _installFirstUse(WhisperModel model) {
    final wait = InstallWait(installModelById(model.id), cancelled: _cancelled);
    _cancelFirstUse = wait.cancel;
    return wait.done.whenComplete(() => _cancelFirstUse = null);
  }

  Transcript _transcript(List<WhisperSegment> segments, String localeId) {
    final timed = [
      for (final s in segments)
        if (s.text.trim().isNotEmpty)
          TranscriptSegment(
            text: s.text.trim(),
            start: s.start,
            end: s.end,
            confidence: s.confidence,
          ),
    ];
    return Transcript(
      fullText: timed.map((s) => s.text).join(' '),
      segments: timed,
      localeId: localeId,
      engineId: id,
      createdAt: _clock(),
    );
  }

  Future<WhisperSession> _sessionFor(WhisperModel model) async {
    await _closing;
    final open = _session;
    if (open != null && _sessionModelId == model.id) return open;
    await _closeSession();
    // whisper.cpp takes any encoder it finds beside the model, so off means
    // gone; a run that held it kept it until now, and an install fetching
    // one drops it itself.
    if (!_accelerated && !_installing.containsKey(model.id)) await _deleteEncoder(model);
    final releases = _releases;
    try {
      final session = await _runtime.load(_file(model));
      // A release during the load closed this session with the runtime.
      if (releases != _releases) throw _cancelled;
      _session = session;
      _sessionModelId = model.id;
      return session;
    } on WhisperRuntimeException catch (e) {
      // A release racing a load that failed is still a cancel; the next run
      // loads again.
      if (releases != _releases) throw _cancelled;
      throw ModelInstallFailed(
        'model failed to load: ${e.message}',
        reason: ModelInstallReason.loadFailed,
        modelId: model.id,
      );
    }
  }

  Future<void> _closeSession() {
    final open = _session;
    _session = null;
    _sessionModelId = null;
    if (open == null) return _closing;
    return _closing = _closing.then((_) => open.close()).catchError((Object _) {});
  }

  @override
  Future<void> release() {
    _releases++;
    return _closing = _closeSession().then((_) => _runtime.dispose()).catchError((Object _) {});
  }

  @override
  Future<void> cancelBatches() async {
    _generation++;
    _session?.abort();
    final cancelFirstUse = _cancelFirstUse;
    _cancelFirstUse = null;
    await cancelFirstUse?.call();
  }

  @override
  Duration batchBudget(Duration audio) => _batchFloor + audio * _model(_selectedId).budgetFactor;

  @override
  List<ModelOption> get models => [for (final m in whisperCatalog) m.option];

  @override
  String get selectedModelId => _selectedId;

  @override
  Future<void> selectModel(String id) async {
    _selectedId = _model(id).id;
  }

  @override
  Future<Set<String>> installedModels() async => {
    for (final model in whisperCatalog)
      if (await _installed(model)) model.id,
  };

  @override
  Stream<ModelInstallProgress> installModelById(String id) => _install(_model(id), withModel: true);

  @override
  final bool canAccelerate;

  @override
  bool get accelerated => _accelerated;

  @override
  Future<void> setAccelerated(bool on) async {
    if (!canAccelerate) return;
    _accelerated = on;
    if (on) return;
    for (final model in whisperCatalog) {
      await _dropEncoder(model);
    }
  }

  /// Off means gone, except an encoder a run holds (the run's end drops it)
  /// or an install is fetching (its landing or its cancel drops it).
  Future<void> _dropEncoder(WhisperModel model) async {
    if (_running && (model.id == _runningModelId || model.id == _sessionModelId)) return;
    if (_installing.containsKey(model.id)) return;
    if (_sessionModelId == model.id) await _closeSession();
    await _deleteEncoder(model);
  }

  @override
  Future<Set<String>> acceleratedModels() async => {
    for (final model in whisperCatalog)
      if (await _acceleratedFor(model)) model.id,
  };

  @override
  Stream<ModelInstallProgress> installAcceleration(String id) =>
      _install(_model(id), withModel: false);

  /// One install turn over [model]: the model file when [withModel] and it
  /// is missing, then the encoder when the switch is on and it is missing,
  /// then, with the model present and no run in flight, the load that
  /// compiles a fresh encoder. The switch is read as each step begins, so a
  /// flip mid-turn decides that step. Fractions cover the bytes of both
  /// files; the unpack and the load ride as preparing.
  Stream<ModelInstallProgress> _install(WhisperModel model, {required bool withModel}) {
    final id = model.id;
    // A manual controller, not async*: a consumer cancel must complete while
    // the fetch is parked, and the turn passes on the stream's own done.
    late final StreamController<ModelInstallProgress> controller;
    StreamSubscription<double>? fetching;
    // A consumer cancel completes done without closing the controller, so
    // "gone" is the listener, not the closed flag.
    bool gone() => controller.isClosed || !controller.hasListener;
    var released = false;
    void release() {
      if (released) return;
      released = true;
      _decrement(_installing, id);
    }

    Future<void> finish() async {
      release();
      if (gone()) return;
      controller.add(const ModelInstallProgress(fraction: 1, done: true));
      await controller.close();
    }

    Future<void> fail(Object error, StackTrace stack) async {
      release();
      if (gone()) return;
      controller.addError(
        error is ModelInstallFailed && error.modelId == null
            ? ModelInstallFailed(
                error.message,
                assetStatus: error.assetStatus,
                reason: error.reason,
                modelId: id,
              )
            : error,
        stack,
      );
      await controller.close();
    }

    void report(double fraction, {bool preparing = false}) {
      if (!gone()) {
        controller.add(ModelInstallProgress(fraction: fraction, done: false, preparing: preparing));
      }
    }

    // A fetch parked behind a cancel resolves like a landing: null.
    Future<(Object, StackTrace)?> fetch(WhisperFile file, File into, double from, double share) {
      final done = Completer<(Object, StackTrace)?>();
      fetching = _fetcher
          .fetch(file.source, into: into, expectedBytes: file.bytes, expectedSha256: file.sha256)
          .listen(
            // The fetcher's own 1 is withheld: done is the engine's word.
            (fraction) {
              if (fraction < 1) report(from + fraction * share);
            },
            onError: (Object error, StackTrace stack) {
              if (!done.isCompleted) done.complete((error, stack));
            },
            onDone: () {
              if (!done.isCompleted) done.complete(null);
            },
          );
      return done.future;
    }

    Future<void> begin() async {
      if (gone()) return release();
      await _removals[id]?.future;
      if (gone()) return release();
      // An extra file for a model that is not there has nothing to speed up.
      if (!withModel && !await _installed(model)) return finish();
      final needModel = withModel && !await _installed(model);
      var needEncoder = _accelerated && !await _acceleratedFor(model);
      if (!needModel && !needEncoder) return finish();
      if (gone()) return release();
      // The turn's first word, so a waiting consumer knows the queue moved.
      report(0);
      final total = (needModel ? model.option.bytes : 0) + (needEncoder ? model.encoder.bytes : 0);
      var from = 0.0;
      if (needModel) {
        final share = model.option.bytes / total;
        final failure = await fetch(model.file, _file(model), from, share);
        if (failure != null) return fail(failure.$1, failure.$2);
        if (gone()) return release();
        if (!await _installed(model)) {
          return fail(
            const ModelInstallFailed(
              'the file is not the catalog\'s length',
              reason: ModelInstallReason.rejected,
            ),
            StackTrace.current,
          );
        }
        from += share;
        // A switch flipped on during the download still gets its encoder.
        needEncoder = _accelerated && !await _acceleratedFor(model);
        if (needEncoder && from >= 1) from = 0;
      }
      if (!needEncoder) return finish();
      final zip = _encoderZip(model);
      final failure = await fetch(model.encoder, zip, from, 1 - from);
      if (failure != null) return fail(failure.$1, failure.$2);
      if (gone()) return release();
      // A switch flipped off during the download leaves nothing behind.
      if (!_accelerated) {
        await _deleteEncoder(model);
        return finish();
      }
      report(1, preparing: true);
      try {
        await _unpackEncoder(model, zip);
      } catch (e, stack) {
        await _deleteEncoder(model);
        return fail(
          e is ModelInstallFailed ? e : ModelInstallFailed('$e', reason: _installReason(e)),
          stack,
        );
      }
      if (!_accelerated) {
        await _deleteEncoder(model);
        return finish();
      }
      if (await _installed(model)) {
        try {
          await _warmUp(model);
        } on ModelInstallFailed catch (e, stack) {
          return fail(e, stack);
        } on TranscriptionFailed {
          // A release during the load; the next run loads again.
        }
      }
      await finish();
    }

    controller = StreamController<ModelInstallProgress>(
      onListen: () {
        _installing[id] = (_installing[id] ?? 0) + 1;
        final previous = _installs;
        _installs = controller.done;
        unawaited(previous.then((_) => begin()).catchError(fail));
      },
      onCancel: () async {
        release();
        await fetching?.cancel();
        if (!_accelerated) await _dropEncoder(model);
      },
    );
    return controller.stream;
  }

  static ModelInstallReason _installReason(Object error) =>
      error is FileSystemException && error.osError?.errorCode == enospc
      ? ModelInstallReason.noSpace
      : ModelInstallReason.rejected;

  Future<void> _unpackEncoder(WhisperModel model, File zip) async {
    final staging = _encoderStaging(model);
    if (await staging.exists()) await staging.delete(recursive: true);
    await extractZip(zip, staging);
    final unpacked = Directory('${staging.path}/${model.encoderDirName}');
    if (!await unpacked.exists()) {
      throw const ModelInstallFailed(
        'the archive holds no encoder directory',
        reason: ModelInstallReason.rejected,
      );
    }
    final target = _encoderDir(model);
    if (await target.exists()) await target.delete(recursive: true);
    await unpacked.rename(target.path);
    await staging.delete(recursive: true);
    await zip.delete();
  }

  /// Loads the model once, on the run chain, so the encoder's compile is
  /// paid here and not by the first entry. Skipped under a run in flight
  /// (its own load pays it, and the run may be the one waiting on this
  /// install); a load that fails keeps the files and throws, so the install
  /// says the model will not open; a model other than the choice is closed
  /// again.
  Future<void> _warmUp(WhisperModel model) {
    if (_running || !_accelerated) return Future.value();
    final load = _batches.then((_) async {
      if (_running || !_accelerated) return;
      await _closeSession();
      await _sessionFor(model);
      if (model.id != _selectedId) await _closeSession();
    });
    _batches = load.then((_) {}, onError: (Object _) {});
    return load;
  }

  @override
  Future<bool> removeModel(String id) async {
    final model = _model(id);
    if (_holding.containsKey(model.id) || _installing.containsKey(model.id)) return false;
    final pending = _removals[model.id];
    if (pending != null) {
      await pending.future;
      return false;
    }
    // Registered before its first await: a run queued from here on waits it.
    final done = _removals[model.id] = Completer<void>();
    try {
      return await _remove(model);
    } finally {
      _removals.remove(model.id);
      done.complete();
    }
  }

  Future<bool> _remove(WhisperModel model) async {
    if (_sessionModelId == model.id) await _closeSession();
    await _deleteEncoder(model);
    final file = _file(model);
    final part = File('${file.path}$modelPartSuffix');
    if (await part.exists()) await part.delete();
    if (!await file.exists()) return false;
    await file.delete();
    return true;
  }

  @override
  Future<bool> isModelInstalled({required String localeId}) => _installed(_model(_selectedId));

  @override
  Stream<ModelInstallProgress> installModel({required String localeId}) =>
      installModelById(_selectedId);

  @override
  Future<List<String>> installedLocales() async =>
      await _installed(_model(_selectedId)) ? supportedLocales() : const [];

  @override
  Future<LocaleModelStatus> localeStatus({required String localeId}) async {
    final resolved = _codeFor(localeId) == null ? null : whisperResolvedTag(localeId);
    if (resolved == null) {
      return LocaleModelStatus(
        status: ModelAssetStatus.unsupported,
        reserved: false,
        resolvedTag: localeId,
      );
    }
    return LocaleModelStatus(
      status: await _installed(_model(_selectedId))
          ? ModelAssetStatus.installed
          : ModelAssetStatus.supported,
      reserved: true,
      resolvedTag: resolved,
    );
  }

  @override
  Future<bool> removeLanguage({required String localeId}) async => false;

  @override
  Future<ReservationInfo> reservationInfo() async =>
      const ReservationInfo(max: 0, reservedTags: []);
}
