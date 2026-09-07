import 'dart:async';
import 'dart:io';

import 'package:transcriber/src/transcribe/transcript.dart';
import 'package:transcriber/src/transcribe/transcription_engine.dart';
import 'package:transcriber/src/transcribe/transcription_exception.dart';
import 'package:transcriber/src/whisper/model_fetcher.dart';
import 'package:transcriber/src/whisper/pcm_decoder.dart';
import 'package:transcriber/src/whisper/whisper_catalog.dart';
import 'package:transcriber/src/whisper/whisper_runtime.dart';

// ignore_for_file: prefer_initializing_formals
// Public parameters assigned to private fields; the lint wants the fields public.

/// whisper.cpp as a batch-only engine: one downloaded model serves every
/// language it knows. The per-language [ManagedModelEngine] questions answer
/// for the selected model, so the app's language surfaces keep working
/// unchanged; the model choice itself is [ModelChoiceEngine]. The language
/// list follows the selected model: every model knows the same ninety-nine,
/// and the large-v3 family adds Cantonese.
///
/// Guarantees a caller may rely on: audio never leaves the device, and the
/// only connection the engine ever opens is the [ModelFetcher]'s, for a
/// catalog file the user asked for or, the managed-engine convention, the
/// selected model's first use; a transcription decodes exactly the requested
/// slice through the [PcmDecoder] and deletes the scratch file whether the run
/// lands or fails; runs are serialized, and [cancelBatches] ends the one in
/// flight (its first-use download included) and drops the queued ones; the
/// service pre-installs a missing model before a run, and the engine's own
/// first-use install is the fallback for any other caller; a
/// model file counts as installed only when its length matches the catalog
/// (the hash was verified at install); [installedModels], [localeStatus] and
/// the other preflights never throw.
class WhisperEngine
    implements
        TranscriptionEngine,
        ManagedModelEngine,
        CancellableBatchEngine,
        ModelChoiceEngine,
        PacedBatchEngine,
        ReleasableEngine {
  WhisperEngine({
    required Directory modelsDir,
    required ModelFetcher fetcher,
    required PcmDecoder decoder,
    required WhisperRuntime runtime,
    String initialModelId = whisperDefaultModelId,
    DateTime Function()? clock,
  }) : _modelsDir = modelsDir,
       _fetcher = fetcher,
       _decoder = decoder,
       _runtime = runtime,
       _clock = clock ?? DateTime.now {
    _selectedId = _model(initialModelId).id;
  }

  static const String engineId = 'whisper.cpp';
  static const _batchFloor = Duration(minutes: 2);
  static const _cancelled = TranscriptionFailed('cancelled');

  final Directory _modelsDir;
  final ModelFetcher _fetcher;
  final PcmDecoder _decoder;
  final WhisperRuntime _runtime;
  final DateTime Function() _clock;

  late String _selectedId;
  WhisperSession? _session;
  String? _sessionModelId;
  Future<void> _closing = Future<void>.value();
  Future<void> _batches = Future<void>.value();
  Future<void> _installs = Future<void>.value();
  // Bumped by cancelBatches; a run queued before the bump never starts.
  int _generation = 0;
  bool _running = false;
  // The model the run in flight is loading or using, whatever the choice
  // moved to since.
  String? _runningModelId;
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
  }) async {
    final language = _codeFor(localeId);
    if (language == null) throw OnDeviceUnavailable('unsupported: $localeId');
    final generation = _generation;
    final run = _batches.then(
      (_) => _transcribe(audio, localeId, language, start, end, generation),
    );
    // The chain only sequences; one failure must not poison every later run.
    _batches = run.then((_) {}, onError: (Object _) {});
    return run;
  }

  Future<Transcript> _transcribe(
    File audio,
    String localeId,
    String language,
    Duration? start,
    Duration? end,
    int generation,
  ) async {
    if (generation != _generation) throw _cancelled;
    final model = _model(_selectedId);
    _running = true;
    _runningModelId = model.id;
    try {
      if (!await _installed(model)) await _installFirstUse(model);
      if (generation != _generation) throw _cancelled;
      final session = await _sessionFor(model);
      if (generation != _generation) throw _cancelled;
      final DecodedPcm decoded;
      try {
        decoded = await _decoder.decode(audio, start: start, end: end);
      } on PcmDecodeFailed catch (e) {
        if (e.code == PcmDecodeFailed.missing) throw RecordingMissing(e.message);
        throw TranscriptionFailed('decode failed: ${e.message}');
      }
      final List<WhisperSegment> segments;
      try {
        if (generation != _generation) throw _cancelled;
        segments = await session.run(decoded.file, language: language);
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
      return _transcript(segments, localeId);
    } finally {
      _running = false;
      _runningModelId = null;
    }
  }

  Future<void> _installFirstUse(WhisperModel model) {
    final done = Completer<void>();
    final install = installModelById(model.id).listen(
      null,
      onError: (Object error, StackTrace stack) {
        if (!done.isCompleted) done.completeError(error, stack);
      },
      onDone: () {
        if (!done.isCompleted) done.complete();
      },
    );
    // A cancelled subscription fires neither done nor error; the waiter is
    // failed here so the run ends instead of parking forever.
    _cancelFirstUse = () async {
      await install.cancel();
      if (!done.isCompleted) done.completeError(_cancelled);
    };
    return done.future.whenComplete(() => _cancelFirstUse = null);
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
    try {
      final session = await _runtime.load(_file(model));
      _session = session;
      _sessionModelId = model.id;
      return session;
    } on WhisperRuntimeException catch (e) {
      throw ModelInstallFailed(
        'model failed to load: ${e.message}',
        null,
        ModelInstallReason.rejected,
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
  Future<void> release() =>
      _closing = _closeSession().then((_) => _runtime.dispose()).catchError((Object _) {});

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
  Stream<ModelInstallProgress> installModelById(String id) {
    final model = _model(id);
    // A manual controller, not async*: a consumer cancel must complete while
    // the fetch is parked, and the turn passes on the stream's own done.
    late final StreamController<ModelInstallProgress> controller;
    StreamSubscription<double>? fetching;
    // A consumer cancel completes done without closing the controller, so
    // "gone" is the listener, not the closed flag.
    bool gone() => controller.isClosed || !controller.hasListener;
    void release() {
      final left = (_installing[id] ?? 1) - 1;
      if (left <= 0) {
        _installing.remove(id);
      } else {
        _installing[id] = left;
      }
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
      controller.addError(error, stack);
      await controller.close();
    }

    Future<void> begin() async {
      if (gone()) return release();
      if (await _installed(model)) return finish();
      if (gone()) return release();
      fetching = _fetcher
          .fetch(
            model.source,
            into: _file(model),
            expectedBytes: model.option.bytes,
            expectedSha256: model.sha256,
          )
          .listen(
            // The fetcher's own 1 is withheld: done is the engine's word,
            // after the length check.
            (fraction) {
              if (fraction < 1) {
                controller.add(ModelInstallProgress(fraction: fraction, done: false));
              }
            },
            onError: fail,
            onDone: () async {
              if (gone()) return release();
              if (await _installed(model)) return finish();
              await fail(
                const ModelInstallFailed(
                  'the file is not the catalog\'s length',
                  null,
                  ModelInstallReason.rejected,
                ),
                StackTrace.current,
              );
            },
          );
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
      },
    );
    return controller.stream;
  }

  @override
  Future<bool> removeModel(String id) async {
    final model = _model(id);
    if (_running && (model.id == _runningModelId || model.id == _sessionModelId)) return false;
    if (_installing.containsKey(model.id)) return false;
    if (_sessionModelId == model.id) await _closeSession();
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
