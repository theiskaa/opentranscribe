import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:opentranscribe/core/export/file_names.dart';
import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/services/entry_store.dart';
import 'package:opentranscribe/core/utils/word_diff.dart';
import 'package:transcriber/transcriber.dart';

/// Drives the whole loop: capture -> transcribe -> persist, and re-transcribe a
/// kept recording with any engine. Engine-agnostic: it talks only to the
/// contracts, so swapping SpeechAnalyzer for whisper.cpp touches nothing here.
///
/// The settled transcript is a batch pass over the kept file. That is the
/// source of truth: robust to a streaming engine's duration limits, identical to
/// what re-transcription would produce, and the reason raw audio is kept. A
/// streaming engine's live stream is real-time UI first ([liveEvents]), with one
/// exception on the stop path: when the batch throws or settles blank on a take
/// whose live stream carried words, those words are saved (untimed) instead of
/// an empty entry, and the audio is kept regardless of preference so a real
/// batch can replace them. A failure with no live words keeps the recording
/// untranscribed rather than lost, re-transcribable later.
///
/// When the keep-audio preference is off, a recording is discarded after its
/// FIRST successful transcription: the transcript is persisted first, then the
/// file is deleted and the entry becomes transcript-only. Audio is never deleted
/// on a failure path, and a repeat re-transcription never deletes; bulk reclaim
/// is [purgeTranscribedAudio], an explicit action only.
class TranscriptionService {
  TranscriptionService({
    required this._recorder,
    required this._engine,
    required this._store,
    this.localeId = 'en-US',
    this._batchTimeout = const Duration(minutes: 2),
    this._peaksReader,
    DateTime Function()? clock,
    String Function()? idGenerator,
    Future<void> Function(File file)? fileDeleter,
    bool Function()? keepAudio,
  }) : _clock = clock ?? DateTime.now,
       _newId = idGenerator ?? _defaultId,
       _deleteFile = fileDeleter ?? _deleteFileDefault,
       _keepAudio = keepAudio ?? _keepAudioDefault {
    // The one rule, enforced in code: only on-device engines are allowed.
    if (!_engine.onDeviceOnly) {
      throw ArgumentError('TranscriptionService requires an on-device engine: ${_engine.id}');
    }
  }

  final AudioRecorder _recorder;
  TranscriptionEngine _engine;
  final EntryStore _store;

  /// The active engine's id, for surfaces marking the current choice.
  String get engineId => _engine.id;

  /// Tells every model surface to re-read (see [modelStateChanged]), for a
  /// caller whose change the service cannot see land itself: the engine
  /// switch's background locale re-resolution.
  void notifyModelSurfaces() => _notifyModelStateChanged();

  /// Whether the active engine manages downloadable models, for surfaces that
  /// word an unready language (a missing download and a missing system setting
  /// are different stories).
  bool get managesModels => _engine is ManagedModelEngine;

  /// Whether the active engine answers per-language readiness cheaply and
  /// without side effects, so a list surface may refine every row. A managed
  /// engine answers false: its model status is already the per-language truth.
  bool get probesLanguageReadiness =>
      _engine is! ManagedModelEngine && _engine is LanguageReadinessEngine;

  /// The transcription language (a BCP-47 tag), pushed by TranscriptionSettings.
  /// Mutable: a change takes effect on the NEXT recording; a session in flight
  /// keeps the locale it started with, so its live stream and its settled batch
  /// can never diverge.
  String localeId;

  final Duration _batchTimeout;
  final DateTime Function() _clock;
  final String Function() _newId;

  /// Removes an entry's kept audio file. Injected so a delete failure (an iOS
  /// data-protection lock) is testable; defaults to a plain [File.delete].
  final Future<void> Function(File file) _deleteFile;

  static Future<void> _deleteFileDefault(File file) => file.delete();

  /// Whether kept audio survives a successful transcription. Read when a
  /// transcript lands (a stop latches it at save time, deliberately: a flip
  /// mid-backfill must not delete a take stopped under keep-on).
  final bool Function() _keepAudio;

  static bool _keepAudioDefault() => true;

  /// Reads an audio file's amplitude envelope (0..1), injected so the service
  /// can persist a new entry's shape at save time without owning a player.
  /// Null in tests that do not care; the detail screen then backfills on the
  /// first open instead.
  final Future<List<double>> Function(String path)? _peaksReader;

  final StreamController<TranscriptEvent> _live = StreamController<TranscriptEvent>.broadcast();
  final StreamController<Entry> _autoFinalized = StreamController<Entry>.broadcast();
  final StreamController<void> _modelStateChanged = StreamController<void>.broadcast();
  final StreamController<void> _entriesChanged = StreamController<void>.broadcast();
  StreamSubscription<TranscriptEvent>? _liveSub;

  /// Gates the shared [_live] broadcast to the current session. Bumped at the
  /// top of [startRecording] so a superseded session's late flush is dropped
  /// rather than painting the new take with the old text. See [_subscribeLive].
  int _liveGeneration = 0;
  StreamSubscription<CaptureStatus>? _statusSub;
  bool _recording = false;
  bool _paused = false;

  /// Single-flights [reconcileOrphans] so two sweeps never race one snapshot.
  bool _reconciling = false;

  /// How many finalizes sit between claiming the capture and saving its entry.
  /// Across that window the file is finalized on disk (so it probes readable)
  /// while no entry references it yet, and [reconcileOrphans] would adopt it as
  /// a second entry sharing one recording. A count, not a flag: a new take can
  /// start and stop while an older finalize is still in its batch pass.
  int _finalizingCaptures = 0;

  /// How many [adoptImportedEntries] passes are in flight. Same window as
  /// [_finalizingCaptures] and for the same reason: an import moves each staged
  /// recording into the directory BEFORE saving its record, so the file probes
  /// readable while nothing references it.
  int _adoptingImports = 0;

  /// Whether some path holds a readable file in the recordings directory that no
  /// entry references yet, BY DESIGN. [reconcileOrphans] must not walk while
  /// this is true, and must abandon a walk that sees it turn true: its
  /// `referenced` snapshot is taken once and cannot know about such a file.
  bool get _unreferencedByDesign => _finalizingCaptures > 0 || _adoptingImports > 0;

  /// Single-flights [purgeTranscribedAudio]. Deliberately not shared with
  /// [_reconciling]: the Cache screen's clear must not silently no-op because
  /// the launch orphan sweep happens to be running.
  bool _purging = false;

  /// Claimed synchronously at the top of [startRecording], before its awaits, so
  /// two concurrent starts cannot both proceed (and leak a status subscription).
  bool _starting = false;

  /// An `interrupted` event that arrived while `await _recorder.start()` was still
  /// in flight (before `_recording` was true). Latched and replayed once the start
  /// settles, so the auto-finalize is never silently dropped.
  bool _pendingInterruption = false;

  /// The locale captured at [startRecording], driving both the live stream and the
  /// stop-path batch for that session (claimed into a local at finalize, so a new
  /// session starting mid-finalize cannot re-language the old one).
  String? _sessionLocaleId;

  /// The current session's language spans, ascending by audio time. Seeded at
  /// start with one span at 0; [setSessionLocale] appends. More than one span
  /// means a mixed-language take, batched span by span on stop.
  List<({int startMs, String tag})> _sessionSpans = [];

  /// Live text heard this session, retained ONLY to salvage a take whose
  /// settling batch yields nothing: the batch stays the source of truth, but a
  /// take the user watched being written must not save as an empty entry when
  /// the engine's file pass fails on audio its live pass understood (the
  /// classic engine does exactly this in some locales). Two parts because a
  /// mid-take language switch restarts the live stream: [_sessionLiveCommitted]
  /// holds the finished streams' text, [_sessionLiveCurrent] the running one's
  /// latest partial.
  String _sessionLiveCommitted = '';
  String _sessionLiveCurrent = '';

  String get _sessionLiveText => [
    _sessionLiveCommitted,
    _sessionLiveCurrent,
  ].where((part) => part.trim().isNotEmpty).join(' ');

  /// The opening span's start round-trip window. A language chosen before any
  /// audio (the queued switch that fires the instant start() resolves) can read
  /// a few milliseconds of scheduling latency as elapsed audio; a switch this
  /// close to the START of a take is treated as choosing the take's language,
  /// not as a mid-take switch, so it yields a single-language take
  /// deterministically instead of a spurious sub-second opening span in the old
  /// language. Scoped to the OPENING span on purpose: a mid-take span always
  /// holds real speech (a switch needs a menu round-trip far longer than this),
  /// so it is never swallowed.
  static const int _spanStartGraceMs = 200;

  /// Audio-time accounting from the INJECTED clock (deterministic in tests):
  /// completed audio milliseconds, plus the instant the current live segment
  /// began (null while paused or idle). Span starts are AUDIO time, so pauses
  /// never inflate them past the file they index into.
  int _audioMsAccumulated = 0;
  DateTime? _audioSegmentStart;

  int get _audioNowMs {
    final started = _audioSegmentStart;
    return _audioMsAccumulated +
        (started == null ? 0 : _clock().difference(started).inMilliseconds);
  }

  void _audioClockPause() {
    final started = _audioSegmentStart;
    if (started != null) _audioMsAccumulated += _clock().difference(started).inMilliseconds;
    _audioSegmentStart = null;
  }

  /// The entry saved by an interruption's auto-finalize, so a stop that races it
  /// (arriving after it completed) returns it instead of throwing. Deliberately NOT
  /// set on a user stop: a plain double-stop must keep throwing. Consumed (set back
  /// to null) by whichever hand-out delivers it, and cleared by a successful new
  /// start, so it only ever holds an UNDELIVERED auto-save of the current or
  /// just-ended take. That invariant is what makes [cancelRecording]'s delete safe:
  /// a delivered entry can never be sitting here for a later cancel to destroy.
  Entry? _lastFinalized;

  /// The finalize in flight right now, so a stop that races it (arriving while the
  /// interruption is still saving) awaits the result instead of throwing.
  Future<Entry?>? _finalizing;

  /// The subset of [_finalizing] owned by an interruption, so a racing cancel can
  /// tell an auto-save (which its discard must undo) from a user stop's finalize
  /// (whose caller was promised the entry).
  Future<Entry?>? _interruptionFinalize;

  /// Ids of takes whose failed auto-save the user discarded before
  /// [recoverInterruptedSave] ran for them. Consumed (removed) by that check, so a
  /// racing recovery no-ops instead of resurrecting a take the user just discarded.
  /// Never cleared wholesale; bounded by how rarely a save fails.
  final Set<String> _discardedSaves = {};

  /// The interruption's save-recovery in flight right now ([recoverInterruptedSave]),
  /// so a racing idle [stopRecording] or [cancelRecording] awaits it instead of
  /// treating the session as idle mid-save.
  Future<void>? _recovering;

  /// Live partial/final events while recording, for real-time UI. Errors on the
  /// underlying live stream are forwarded here; they do not affect the persisted
  /// transcript, which comes from the batch pass on stop.
  Stream<TranscriptEvent> get liveEvents => _live.stream;

  /// Capture lifecycle (interruptions, stop) surfaced from the recorder.
  Stream<CaptureStatus> get captureStatus => _recorder.status;

  /// Entries saved automatically because capture was interrupted (a phone call),
  /// rather than by an awaited [stopRecording]. Lets the UI react without a caller.
  /// In the rare stop-races-interruption case the same entry may also be returned by
  /// [stopRecording], so a consumer that both awaits stop and listens here should
  /// dedupe by [Entry.id]. Save failures surface here as stream errors.
  Stream<Entry> get autoFinalized => _autoFinalized.stream;

  bool get isRecording => _recording;

  /// Whether the live capture is paused. False whenever [isRecording] is false.
  bool get isPaused => _paused;

  /// Input level while capturing (0..1, ~20 Hz), for a live waveform. Ephemeral:
  /// silent while paused or idle, nothing replayed, nothing persisted.
  Stream<double> get inputLevel => _recorder.level;

  /// Swaps the active engine. Refused (false) while a take is starting,
  /// recording, or finalizing: a take's live stream and its settled batch must
  /// come from one engine. An in-flight re-transcription is not a refusal; it
  /// holds the engine reference it started with and lands on it. On a change
  /// every model surface is told to reload and the caller re-resolves the
  /// locale default; swapping to the already-active engine is a no-op that
  /// still answers true.
  bool useEngine(TranscriptionEngine engine) {
    if (!engine.onDeviceOnly) {
      throw ArgumentError('TranscriptionService requires an on-device engine: ${engine.id}');
    }
    if (_recording || _starting || _finalizing != null || _finalizingCaptures > 0) return false;
    if (identical(engine, _engine)) return true;
    _engine = engine;
    _notifyModelStateChanged();
    return true;
  }

  /// The BCP-47 tags the engine can transcribe on-device, for a language picker.
  Future<List<String>> supportedLocales() => _engine.supportedLocales();

  /// All saved entries, newest first. The store is the service's private detail;
  /// callers read and mutate entries only through the service, so the entry
  /// lifecycle (audio file + record) has one owner.
  List<Entry> entries() => _store.all();

  /// Preflight: whether transcription can run for [localeId] (defaults to the
  /// service locale). The probe downloads nothing; a managed engine fetches its
  /// model once on first use or via [installModel]. Delegates to the engine.
  /// No UI consumer since the per-language rows took over, KEPT for the
  /// recording preflight gate the recorder still lacks (nothing today warns
  /// before recording in a language whose model is absent).
  Future<Availability> checkAvailability({String? localeId}) =>
      _engine.checkAvailability(localeId: localeId ?? this.localeId);

  /// Prompts for (or reports) microphone permission. Recording gates on this
  /// itself; exposed so onboarding can front-load the prompt. Idempotent - a
  /// second call just reports the settled status.
  Future<PermissionStatus> ensureMicPermission() => _recorder.ensurePermission();

  /// Whether the model is downloaded so transcription runs with no wait. An engine
  /// with no downloadable model answers ready here (the coarse answer;
  /// [localeStatus] refines per language). Kept with [checkAvailability]
  /// for the same future recording gate.
  Future<bool> isModelInstalled({String? localeId}) async {
    final engine = _engine;
    return engine is ManagedModelEngine
        ? engine.isModelInstalled(localeId: localeId ?? this.localeId)
        : true;
  }

  /// Fires after any path that may have changed a model's install state (a
  /// first-use install during transcription, an explicit install, a removal,
  /// or an engine switch and its locale re-resolution), so state layers
  /// re-read instead of polling or going stale.
  Stream<void> get modelStateChanged => _modelStateChanged.stream;

  void _notifyModelStateChanged() {
    if (!_modelStateChanged.isClosed) _modelStateChanged.add(null);
  }

  /// Fires after a store mutation no caller is awaiting a reload for: a
  /// discard landing behind a stop or a re-transcribe, a purge or heal batch,
  /// an orphan recovery. List surfaces re-read instead of showing an entry
  /// whose audio quietly left. Plain delete and rename don't fire; their
  /// callers reload themselves.
  Stream<void> get entriesChanged => _entriesChanged.stream;

  void _notifyEntriesChanged() {
    if (!_entriesChanged.isClosed) _entriesChanged.add(null);
  }

  /// Downloads the model, streaming progress to completion. An engine with no
  /// downloadable model completes instantly. Deliberately `.map`, NOT an
  /// async* wrapper: a consumer cancel must propagate synchronously to the
  /// engine stream, and a generator parked on a silent download (a stuck
  /// asset with no progress ticks) could never be unwound - hanging the
  /// cancel and wedging the engine's install queue behind it.
  Stream<ModelInstallProgress> installModel({String? localeId}) {
    final engine = _engine;
    if (engine is! ManagedModelEngine) {
      return Stream.value(const ModelInstallProgress(fraction: 1, done: true));
    }
    return engine.installModel(localeId: localeId ?? this.localeId).map((progress) {
      if (progress.done) _notifyModelStateChanged();
      return progress;
    });
  }

  /// The tags whose models are downloaded on this device. An engine with no
  /// downloadable model lists everything it supports (the coarse answer;
  /// [localeStatus] refines per language).
  Future<List<String>> installedLocales() {
    final engine = _engine;
    return engine is ManagedModelEngine ? engine.installedLocales() : engine.supportedLocales();
  }

  /// Fine-grained model state for one language. Always explicit: status paths
  /// never default to the service locale, so callers cannot accidentally ask
  /// about "whatever the default is right now".
  Future<LocaleModelStatus> localeStatus(String localeId) async {
    final engine = _engine;
    if (engine is ManagedModelEngine) return engine.localeStatus(localeId: localeId);
    // No managed model to download: readiness is whether the engine can run
    // the language here NOW (for a dictation-style engine, whether the
    // system's own model is present, added in iOS Settings, never by this
    // app). Probed through localeReady, which guarantees no side effects;
    // checkAvailability may raise the speech-permission prompt.
    if (engine is LanguageReadinessEngine) {
      final ready = await engine.localeReady(localeId: localeId);
      return LocaleModelStatus(
        status: ready ? ModelAssetStatus.installed : ModelAssetStatus.unsupported,
        reserved: true,
        resolvedTag: localeId,
      );
    }
    // An engine that cannot say per-language readiness: supported is ready.
    final supported = (await engine.supportedLocales()).contains(localeId);
    return LocaleModelStatus(
      status: supported ? ModelAssetStatus.installed : ModelAssetStatus.unsupported,
      reserved: true,
      resolvedTag: localeId,
    );
  }

  /// Releases this app's claim on a language's model (the platform owns the
  /// shared asset's actual lifetime). Returns whether a claim was released.
  Future<bool> removeLanguage(String localeId) async {
    final engine = _engine;
    if (engine is! ManagedModelEngine) return false;
    final released = await engine.removeLanguage(localeId: localeId);
    if (released) _notifyModelStateChanged();
    return released;
  }

  /// The platform's language cap and current holdings; max 0 when the engine
  /// has no such concept.
  Future<ReservationInfo> reservationInfo() {
    final engine = _engine;
    return engine is ManagedModelEngine
        ? engine.reservationInfo()
        : Future.value(const ReservationInfo(max: 0, reservedTags: []));
  }

  /// Begins a capture. Throws [StateError] if one is already recording or
  /// starting, and [PermissionDenied] if the microphone grant is missing. On a
  /// streaming engine, live text flows on [liveEvents] until the stop.
  Future<void> startRecording() async {
    if (_recording || _starting) {
      throw StateError('already recording');
    }
    // Claimed before the first await: without this, two concurrent starts would
    // both pass the _recording check, double-subscribe, and double-start capture.
    _starting = true;
    // Close the live gate before the permission + mic round trip below, not
    // after: a predecessor flushing late during that window would otherwise
    // still match the gate and paint this take with the old transcript.
    _liveGeneration++;
    try {
      final permission = await _recorder.ensurePermission();
      if (permission != PermissionStatus.granted) {
        throw const PermissionDenied('microphone permission not granted');
      }
      // React to a native interruption (a phone call): finalize and save the entry
      // ourselves so the recording is never left on disk without a record. Only
      // `interrupted` matters; `stopped` is our own stop() echo, already handled.
      // Subscribe before start(): the recorder's status stream does not replay, so a
      // listener attached after start could miss an early event. An event landing
      // before `_recording` is true is latched and replayed below.
      _pendingInterruption = false;
      _statusSub = _recorder.status.listen((status) {
        if (status != CaptureStatus.interrupted) return;
        if (_recording) {
          unawaited(_handleInterruption());
        } else {
          _pendingInterruption = true;
        }
      });
      try {
        await _recorder.start();
      } catch (_) {
        await _statusSub?.cancel();
        _statusSub = null;
        rethrow;
      }
      _recording = true;
      _paused = false;
      // Snapshot the locale for the whole session: live and the stop-path batch
      // must agree even if the setting changes mid-recording.
      _sessionLocaleId = localeId;
      _sessionSpans = [(startMs: 0, tag: localeId)];
      _sessionLiveCommitted = '';
      _sessionLiveCurrent = '';
      _audioMsAccumulated = 0;
      _audioSegmentStart = _clock();
      // Cleared only after start succeeds: a failed start (mic busy during the very
      // call that interrupted us) must not lose the entry a prior finalize saved.
      // All three session handles clear here so a new take starts with none of the
      // previous take's finalize state reachable by a later stop or cancel;
      // _handleInterruption's finally guards with identical(...), so this early
      // clear cannot double-clear a newer finalize that started after it.
      _lastFinalized = null;
      _finalizing = null;
      _interruptionFinalize = null;
      // Replay an interruption that landed while start() was in flight; the capture
      // it killed is real and must be finalized like any other.
      if (_pendingInterruption) {
        _pendingInterruption = false;
        unawaited(_handleInterruption());
      }

      final engine = _engine;
      // The type is the source of truth for streaming; there is no separate flag.
      // Guard on _recording: an interruption replayed just above (a call landing
      // during start()) already finalized this session, so a live subscription now
      // would attach to a dead take - leaked until dispose, and its error would fire
      // the recorder's error surface on a screen the user never sees.
      if (engine is StreamingTranscriptionEngine && _recording) {
        _liveSub = _subscribeLive(engine, _sessionLocaleId ?? localeId);
      }
    } finally {
      _starting = false;
    }
  }

  StreamSubscription<TranscriptEvent> _subscribeLive(
    StreamingTranscriptionEngine engine,
    String tag,
  ) {
    // Stamped with the owning session: a stream can outlive its cancel and
    // flush the whole old transcript late; the next start bumps the gate, so
    // this listener's events are dropped once a newer take exists.
    final generation = _liveGeneration;
    return engine
        .transcribeLive(localeId: tag)
        .listen(
          (event) {
            // The live UI never needs the isFinal event: it only duplicates the
            // last partial, and the batch pass is the source of truth for the
            // saved transcript. It is also the ONLY event a stopped session
            // emits LATE (its graceful finalize flushes after stop), so it is
            // the one that races a new take and paints it with the old text.
            // Drop it here; the engine still uses it to close its own stream.
            if (event.isFinal) return;
            if (generation != _liveGeneration) return;
            _sessionLiveCurrent = event.text;
            if (_live.isClosed) return;
            _live.add(event);
          },
          onError: (Object error, StackTrace stack) {
            if (generation != _liveGeneration || _live.isClosed) return;
            _live.addError(error, stack);
          },
          cancelOnError: false,
        );
  }

  /// Re-languages the CURRENT session from this moment on: a new language
  /// span begins at the current audio time, the settling batch will run each
  /// span in its own language, and the live stream restarts in [tag] (its
  /// text so far was UI-only; the batch is the source of truth, so nothing
  /// already spoken is lost). Session-only by design: the app default is
  /// TranscriptionSettings' job, and a one-take language change must not
  /// silently rewrite it. A no-op when idle.
  Future<void> setSessionLocale(String tag) async {
    if (!_recording || _sessionLocaleId == tag) return;
    // Note: _liveGeneration is bumped only per-recording (startRecording), not
    // here. Within-take correctness of the restart below rests on the engine's
    // session token dropping the old stream's late events, not on that gate.
    _sessionLocaleId = tag;
    final nowMs = _audioNowMs;
    final spans = _sessionSpans;
    // Replace a span that holds no audio instead of opening one after it. Two
    // cases qualify: the switch lands on the exact instant a span began (a rapid
    // toggle, or consecutive switches while the paused clock is frozen), or it
    // lands during the opening span's start round-trip (see [_spanStartGraceMs]).
    // The replacement inherits the removed span's start so nothing before it is
    // uncovered, and a same-instant back-and-forth collapses to a single span.
    // A mid-take span always holds real speech, so it is never swallowed.
    final atStart = spans.length == 1 && spans.first.startMs == 0;
    final coalesces =
        spans.isNotEmpty &&
        (spans.last.startMs == nowMs || (atStart && nowMs <= _spanStartGraceMs));
    var startMs = nowMs;
    if (coalesces) startMs = spans.removeLast().startMs;
    if (spans.isEmpty || spans.last.tag != tag) {
      spans.add((startMs: startMs, tag: tag));
    }
    final engine = _engine;
    if (engine is! StreamingTranscriptionEngine) return;
    final liveSub = _liveSub;
    _liveSub = null;
    // NOT awaited: a live stream mid-session has no next event to resume a
    // cancel on, so awaiting could wedge the switch. Ordering is safe by
    // contract: [StreamingTranscriptionEngine.transcribeLive] promises a new
    // listen works while the old stream's teardown is still completing.
    unawaited(liveSub?.cancel());
    _sessionLiveCommitted = _sessionLiveText;
    _sessionLiveCurrent = '';
    _liveSub = _subscribeLive(engine, tag);
  }

  /// Ends the capture and returns the saved entry. The intricate parts of the
  /// contract: a stop racing an interruption's auto-finalize returns the entry the
  /// interruption saved (in flight or completed) instead of throwing; a plain
  /// double-stop throws [StateError]; a persistence failure throws
  /// [EntrySaveFailed] carrying the entry, recoverable via [retrySave]; a
  /// transcription failure does NOT throw, the entry is saved with the session's
  /// live text when there was one, untranscribed otherwise.
  Future<Entry> stopRecording() async {
    if (_recording) {
      // We were recording, so this call produces the entry. _finalizing is set only
      // for the in-flight window (so a concurrent caller shares the result) and
      // cleared after: a later double-stop must still throw, not replay.
      final future = _stopAndPersist(transcribe: true);
      _finalizing = future;
      try {
        return (await future)!;
      } finally {
        if (identical(_finalizing, future)) _finalizing = null;
      }
    }
    // Not recording: an interruption may be finalizing right now, or may already
    // have saved the entry. Await the in-flight finalize before giving up, so a
    // stop landing mid-save returns the entry instead of throwing.
    final pending = _finalizing;
    if (pending != null) {
      try {
        final entry = await pending;
        if (entry != null) {
          if (identical(_lastFinalized, entry)) _lastFinalized = null;
          return entry;
        }
      } on EntrySaveFailed {
        // The audio was finalized but its record was not saved; this caller needs
        // the entry (carried by the error) to retrySave. Never downgrade this to
        // "not recording": for a concurrent user stop the error surfaced nowhere
        // else, and orphaning would follow.
        rethrow;
      } catch (_) {
        // CaptureFailed etc.: nothing was captured, nothing to return.
      }
    }
    // A save-recovery may be mid-flight (recoverInterruptedSave, racing this
    // stop from the cubit's unawaited call). Await it so a completed recovery's
    // stamped _lastFinalized is what the hand-out below sees, instead of falling
    // through to a bogus 'not recording' while the entry lands moments later.
    final recovering = _recovering;
    if (recovering != null) {
      try {
        await recovering;
      } catch (_) {
        // Errors are reported through recoverInterruptedSave's own caller.
      }
    }
    final last = _lastFinalized;
    if (last != null) {
      _lastFinalized = null;
      return last;
    }
    throw StateError('not recording');
  }

  /// Finalizes a capture exactly once: stops the recorder, optionally runs the batch
  /// pass, and persists the entry. The guard is a synchronous early-return followed
  /// by claiming `_recording = false`, with no await between, so a user stop racing an
  /// interruption cannot both proceed; the loser returns early. `_statusSub` is
  /// cancelled up front, before the first await, so a second `interrupted` event
  /// during `_recorder.stop()` cannot re-enter `_handleInterruption`. Returns null
  /// only when nothing was recording. The [_finalizingCaptures] claim rides the
  /// same synchronous block, so every path here (a stop, an interruption, a
  /// termination) hides its file from [reconcileOrphans] until the entry lands.
  /// One exception, deliberate: on the [EntrySaveFailed] path the claim is
  /// released with the file finalized and no record pointing at it, because
  /// holding it would disable the sweep for the rest of the process. The sweep
  /// recovering that file is the intended outcome; see [recoverInterruptedSave]
  /// for how a retry avoids duplicating it.
  Future<Entry?> _stopAndPersist({required bool transcribe}) async {
    if (!_recording) {
      final last = _lastFinalized;
      _lastFinalized = null;
      return last;
    }
    _recording = false;
    _paused = false;
    // Claim ALL session state synchronously with the claim above: a new recording
    // may start while this finalize is still awaiting, and this (older) finalize
    // must neither cancel the new session's subscriptions nor read its locale.
    final liveSub = _liveSub;
    _liveSub = null;
    final statusSub = _statusSub;
    _statusSub = null;
    final sessionLocale = _sessionLocaleId;
    final spans = _sessionSpans;
    _sessionSpans = [];
    // The live text is NOT claimed here: the recognizer's end-of-audio flush
    // lands during the recorder stop below, and reading now would drop the last
    // words the user watched arrive. The generation is the claim instead: a
    // newer session bumps it before touching the live-text fields, so the
    // deferred read can never absorb another take's words.
    final liveGeneration = _liveGeneration;
    _audioClockPause();
    try {
      // Inside the try, and still in the same synchronous block as the flips
      // above (nothing between them awaits), so the claim can never leak: a
      // leaked one is unrecoverable, silencing [reconcileOrphans] for the
      // process.
      _finalizingCaptures++;
      await statusSub?.cancel();
      final recording = await _recorder.stop();
      // UI-only; released here (not after the batch) so the next take's live
      // session is not queued behind it. Re-awaited in the finally; a cancel
      // rejection is swallowed on both copies, or this detached one would hit
      // the zone and the finally would fail a stop that fully succeeded.
      unawaited(liveSub?.cancel().catchError((_) {}));

      var liveText = '';
      if (_liveGeneration == liveGeneration) {
        liveText = _sessionLiveText.trim();
        _sessionLiveCommitted = '';
        _sessionLiveCurrent = '';
      }

      // The recording reference is a filename; resolve it to an absolute path to open
      // the file, but persist the reference verbatim so it survives a backup/restore.
      Transcript? transcript;
      var salvaged = false;
      if (transcribe) {
        try {
          final audioFile = File(await _resolveAudioPath(recording.path));
          transcript = spans.length > 1
              ? await _segmentedBatch(_engine, audioFile, recording.duration, spans)
              : await _batch(_engine, audioFile, recording.duration, localeId: sessionLocale);
          // A first-use model install may have piggybacked on this pass.
          _notifyModelStateChanged();
        } catch (_) {
          // Any failure keeps the recording untranscribed rather than losing it; it
          // can be re-transcribed later. Never let a transcription error orphan audio.
          transcript = null;
        }
        // A take the user watched being written must not settle empty because the
        // engine's file pass failed on audio its live pass understood. The live
        // text stands in (untimed, so no segments), and the audio is kept below
        // regardless of the preference so a better pass can replace this one.
        if (liveText.isNotEmpty && (transcript?.fullText.trim().isEmpty ?? true)) {
          salvaged = true;
          transcript = Transcript(
            fullText: liveText,
            segments: const [],
            localeId: spans.isNotEmpty ? spans.first.tag : (sessionLocale ?? localeId),
            engineId: _engine.id,
            createdAt: _clock(),
          );
        }
      }

      final entry = Entry(
        id: _newId(),
        createdAt: _clock(),
        audioPath: recording.path,
        duration: recording.duration,
        transcript: transcript,
        // Stamped even when transcription was skipped or failed: an entry
        // saved untranscribed (interruption, dispose, failed batch) must
        // still know what language it is in when transcribed later. A mixed
        // take's recording language is its FIRST span's, and its spans are
        // kept so a later (re-)transcription can rebuild the mix.
        recordedLocaleId: spans.isNotEmpty ? spans.first.tag : sessionLocale,
        languageSpans: spans.length > 1
            ? [for (final span in spans) LanguageSpan(startMs: span.startMs, localeId: span.tag)]
            : null,
      );
      try {
        await _store.save(entry);
      } catch (error) {
        // A failed save is the one real hole in "audio never orphaned": the file is
        // finalized but no record points at it. Throw the entry with the failure so
        // the caller can retry via [retrySave] instead of losing the reference.
        throw EntrySaveFailed(entry, error);
      }
      // Off the critical path: the entry is saved and returned now; its wave
      // shape lands in a follow-up write so the first open never re-decodes
      // the whole file. Under keep-audio off the discard chains AFTER the
      // backfill, so the waveform is captured before the file disappears. The
      // returned entry deliberately still carries its path: the store is the
      // truth, and surfaces refresh from it.
      // An empty landing keeps the audio: it is the only path back to the words.
      // So does a salvaged one: its text is the live stream's approximation, and
      // the audio is the only way a real batch can ever replace it.
      final discard =
          !salvaged && transcript != null && transcript.fullText.trim().isNotEmpty && !_keepAudio();
      unawaited(
        _backfillPeaks(entry).then((_) async {
          if (discard) await _discardAudio(entry.id);
        }),
      );
      return entry;
    } finally {
      try {
        await liveSub?.cancel();
      } catch (_) {
        // The subscription is dead either way; the outcome above stands.
      }
      // After the cancel, not before: that cancel is a native recognizer
      // teardown, and the file would otherwise be unguarded for its duration.
      _finalizingCaptures--;
    }
  }

  /// Suspends the capture: the mic goes silent, the file stays open, and the
  /// session (including its live transcription) survives to [resumeRecording]
  /// or a normal stop. Throws [StateError] when nothing is recording or already
  /// paused; a lost race against a concurrent pause/resume surfaces as the
  /// recorder's [CaptureFailed] instead. The paused flag flips only after the
  /// recorder confirms, and only if the session is still alive: a stop or
  /// interruption landing during the await must not leave paused chrome on an
  /// idle screen.
  Future<void> pauseRecording() async {
    if (!_recording || _paused) {
      throw StateError(_recording ? 'already paused' : 'not recording');
    }
    await _recorder.pause();
    if (_recording) {
      _paused = true;
      _audioClockPause();
    }
  }

  /// Resumes a paused capture into the same recording. Throws [StateError] when
  /// not paused; a recorder failure propagates and leaves the session paused,
  /// still stoppable and cancellable.
  Future<void> resumeRecording() async {
    if (!_recording || !_paused) {
      throw StateError(_recording ? 'not paused' : 'not recording');
    }
    await _recorder.resume();
    if (_recording) {
      _paused = false;
      _audioSegmentStart = _clock();
    }
  }

  /// Ends the capture and discards it: no entry, no kept audio. The claim
  /// discipline mirrors [_stopAndPersist] (synchronous flips, status
  /// subscription cancelled before the first await) so a racing interruption
  /// cannot double-finalize. Quiet when nothing is recording, except one case:
  /// an interruption that claimed the session auto-saves it, and a discard must
  /// win over that save whether the finalize is still in flight (awaited, then
  /// its entry deleted) or already completed ([_lastFinalized] holds it, deleted
  /// directly). [_lastFinalized] is set only by an interruption path and cleared
  /// by the next [startRecording], so this can only ever delete the auto-saved
  /// take the user is currently looking at, never a user-stop's entry (a user
  /// stop never sets it) and never a previous take (a new start clears it). It
  /// also cannot delete a DELIVERED entry: every hand-out of [_lastFinalized]
  /// (a stop returning it, in flight or already completed) consumes it first, so
  /// a caller who already received the entry has, by construction, taken it out
  /// of this branch's reach; this completed-save branch can only ever discard
  /// the still-undelivered auto-save of the take on screen. Throws [StateError]
  /// during an in-flight start, which cannot be safely undone from here.
  Future<void> cancelRecording() async {
    if (_starting) throw StateError('start in flight');
    if (!_recording) {
      // The capture this cancel meant to discard may just have been claimed by
      // an interruption's auto-finalize. The save is real, but the user's
      // intent is discard: wait it out and take the entry back. A user-stop's
      // finalize is deliberately NOT touched; its caller was promised the entry.
      final pending = _interruptionFinalize;
      if (pending != null) {
        Entry? saved;
        try {
          saved = await pending;
        } on EntrySaveFailed catch (e) {
          // The record never saved, but the audio is on disk: the user's cancel
          // must still discard it, or reconcileOrphans resurrects the take next
          // launch. deleteEntry removes the orphaned file (the record delete is a
          // no-op). Best-effort: a failed discard falls back to that sweep.
          // Marked before the delete so a racing recoverInterruptedSave (either
          // order) never resurrects the discarded take.
          _discardedSaves.add(e.entry.id);
          try {
            await deleteEntry(e.entry);
          } catch (_) {}
        } catch (_) {
          // Nothing was captured (CaptureFailed) or another failure: nothing kept.
        }
        if (saved != null) {
          if (identical(_lastFinalized, saved)) _lastFinalized = null;
          try {
            await deleteEntry(saved);
          } catch (_) {
            // Best effort, like the save-failed branch above: a locked file
            // keeps its record and the user deletes it visibly instead.
          }
        }
        return;
      }
      // A save-recovery may be mid-flight (recoverInterruptedSave, racing this
      // cancel from the cubit's unawaited call). Await it so a completed recovery's
      // stamped _lastFinalized is what the check below sees and discards, instead
      // of missing it by milliseconds and leaving the recovered take saved.
      final recovering = _recovering;
      if (recovering != null) {
        try {
          await recovering;
        } catch (_) {
          // Errors are reported through recoverInterruptedSave's own caller.
        }
      }
      // The interruption's finalize already completed by the time this cancel
      // arrived; the save it left behind is the same take the user just asked
      // to discard.
      final finalized = _lastFinalized;
      if (finalized != null) {
        _lastFinalized = null;
        try {
          await deleteEntry(finalized);
        } catch (_) {
          // Best effort, same rule as the in-flight branch: a locked file keeps
          // its record and the user deletes it visibly instead.
        }
      }
      return;
    }
    _recording = false;
    _paused = false;
    final liveSub = _liveSub;
    _liveSub = null;
    final statusSub = _statusSub;
    _statusSub = null;
    _sessionLocaleId = null;
    _sessionLiveCommitted = '';
    _sessionLiveCurrent = '';
    await statusSub?.cancel();
    try {
      await _recorder.cancel();
    } on CaptureFailed {
      // Nothing captured or capture already dead: discarding was the goal.
    } finally {
      try {
        await liveSub?.cancel();
      } catch (_) {
        // The subscription is dead either way; the outcome above stands.
      }
    }
  }

  /// Whether a stored entry OTHER than [exceptId] already references the file
  /// [audioPath] names. Two entries on one recording is never a state the app
  /// creates on purpose, but a retry racing [reconcileOrphans] can produce it,
  /// and every file delete below must survive it: deleting a shared file would
  /// leave the survivor pointing at nothing, and a swept twin is untranscribed,
  /// so [healDanglingAudio] would never repair it.
  bool _referencedElsewhere(String audioPath, String exceptId) {
    final name = baseName(audioPath);
    return _store.all().any(
      (e) => e.id != exceptId && e.audioPath != null && baseName(e.audioPath!) == name,
    );
  }

  /// The basenames more than one stored entry references, for the bulk sweeps:
  /// one pass over the journal instead of [_referencedElsewhere] per entry,
  /// which would decrypt the whole journal once per discard. Snapshotted, so a
  /// name that stops being shared mid-sweep is simply left for the next run.
  Set<String> _sharedAudioNames() {
    final seen = <String>{}, shared = <String>{};
    for (final entry in _store.all()) {
      final path = entry.audioPath;
      if (path != null && !seen.add(baseName(path))) shared.add(baseName(path));
    }
    return shared;
  }

  /// Retries persisting an entry whose save failed ([EntrySaveFailed]). The entry
  /// already references its kept audio, so a successful retry fully recovers it.
  /// A no-op when [reconcileOrphans] already adopted that file under a record of
  /// its own: the audio is recovered either way, and this is the only path that
  /// could put two entries on one recording. Pure: no side effects, so
  /// [dispose]/[finalizeActiveCapture] can use it during teardown without
  /// touching the controllers they are closing.
  Future<void> retrySave(Entry entry) async {
    final path = entry.audioPath;
    if (path != null && _referencedElsewhere(path, entry.id)) return;
    await _store.save(entry);
  }

  /// Adopts entries restored from an archive, keeping the entry lifecycle's
  /// single owner: per entry, the staged audio moves into the recordings
  /// directory BEFORE the record is saved, so a kill mid-import leaves a
  /// probeable orphan the launch sweep recovers, never a record pointing at
  /// nothing. Merge is by id: an identical stored entry is skipped (re-import
  /// is a no-op), a differing one is overwritten with the archive's. An
  /// overwritten record's old audio file is deleted only when the archive
  /// brought REPLACEMENT audio and nothing else references the old file; a
  /// transcript-only record never destroys a local recording (the sweep
  /// resurrects the file as a visible orphan instead). A basename already
  /// owned by a different entry sends the restored audio under a fresh name;
  /// filenames are not identity, ids are. Fires [entriesChanged] once when
  /// anything changed, even when a later entry's adoption failed midway.
  /// [reconcileOrphans] is blocked for the whole pass, not just the move-to-save
  /// gap: it snapshots what is referenced once, so any record saved after that
  /// snapshot is invisible to it and its file would be adopted a second time.
  Future<AdoptResult> adoptImportedEntries(List<StagedImportEntry> staged) async {
    var added = 0;
    var updated = 0;
    var unchanged = 0;
    var audioRestored = 0;
    var changed = false;
    final owners = <String, String>{
      for (final stored in _store.all())
        if (stored.audioPath != null) baseName(stored.audioPath!): stored.id,
    };
    try {
      // First statement in the try so it can never leak, like the finalize
      // claim: between the move and the save each restored file is readable
      // with nothing referencing it, which is exactly what the sweep adopts.
      _adoptingImports++;
      for (final item in staged) {
        var entry = item.entry;
        final existing = _store.read(entry.id);
        if (item.stagedAudio != null && entry.audioPath != null) {
          final (adopted, restored) = await _adoptRestoredAudio(
            entry,
            item.stagedAudio!,
            owners,
            existing,
          );
          entry = adopted;
          if (restored) audioRestored++;
        }
        if (existing == entry) {
          unchanged++;
          continue;
        }
        await _store.save(entry);
        changed = true;
        existing == null ? added++ : updated++;
        await _reapReplacedAudio(existing, entry, owners);
      }
    } finally {
      _adoptingImports--;
      if (changed) _notifyEntriesChanged();
    }
    return AdoptResult(
      added: added,
      updated: updated,
      unchanged: unchanged,
      audioRestored: audioRestored,
    );
  }

  /// Moves one staged recording into place, renaming when [owners] says the
  /// basename belongs to a different entry. Returns the (possibly renamed)
  /// entry and whether a file actually landed.
  Future<(Entry, bool)> _adoptRestoredAudio(
    Entry entry,
    File stagedAudio,
    Map<String, String> owners,
    Entry? existing,
  ) async {
    var name = baseName(entry.audioPath!);
    final owner = owners[name];
    if (owner != null && owner != entry.id) {
      // A rename this entry already went through on an earlier import of the
      // same archive is reused, or every re-import would mint another name
      // and rewrite the record: re-import must stay a no-op.
      final adopted = existing?.audioPath;
      name = adopted != null && owners[baseName(adopted)] == entry.id
          ? baseName(adopted)
          : 'otr-import-${_newId()}${extensionOf(name)}';
      entry = entry.withAudioPath(name);
    }
    owners[name] = entry.id;
    final destination = File(await _resolveAudioPath(name));
    if (destination.existsSync()) return (entry, false);
    await _moveIntoRecordings(stagedAudio, destination);
    return (entry, true);
  }

  /// Deletes an overwritten record's old audio file, but only when the new
  /// record carries audio of its own and no stored entry still references the
  /// old file. [owners] maps a basename to its LAST claimant, so it can
  /// detect collisions but not prove uniqueness; the reap re-checks against
  /// the store, the source of truth.
  Future<void> _reapReplacedAudio(Entry? existing, Entry entry, Map<String, String> owners) async {
    final oldAudio = existing?.audioPath;
    if (oldAudio == null || entry.audioPath == null) return;
    final basename = baseName(oldAudio);
    if (basename == entry.audioPath) return;
    final referenced = _store.all().any(
      (e) => e.audioPath != null && baseName(e.audioPath!) == basename,
    );
    if (referenced) return;
    owners.remove(basename);
    try {
      await _deleteFile(File(await _resolveAudioPath(oldAudio)));
    } catch (_) {
      // Best effort: a survivor is recovered as an orphan next launch,
      // visible rather than lost.
    }
  }

  /// Rename first (atomic within a volume); a cross-volume staging dir falls
  /// back to copy-then-delete, ordered so the recordings-side file is whole
  /// before the staging copy disappears.
  Future<void> _moveIntoRecordings(File staged, File destination) async {
    try {
      await staged.rename(destination.path);
    } on FileSystemException {
      await staged.copy(destination.path);
      await staged.delete();
    }
  }

  /// Recovers an interruption's auto-save after it failed and surfaced on
  /// [autoFinalized] as an [EntrySaveFailed]. Persists the entry, then
  /// re-announces it on [autoFinalized] as a normal event so list surfaces
  /// refresh. Sets [_lastFinalized] only while idle, so a take that started
  /// meanwhile keeps its own double-stop contract (a stale entry must never be
  /// handed to a new take's stop).
  ///
  /// Silently does nothing when [reconcileOrphans] already adopted the audio
  /// under its own record: that record IS the recovery, and saving this one too
  /// would double the take. Nothing is announced then either, or [_lastFinalized]
  /// would hand out an entry the store does not hold.
  ///
  /// Also a no-op when the user's [cancelRecording] already discarded this take
  /// (either arrival order is safe, see [_discardedSaves]). While the save is in
  /// flight, [_recovering] holds it: both [stopRecording] and [cancelRecording]
  /// await it before deciding idle, so a racing stop or cancel gets the recovered
  /// entry delivered (or discarded) instead of a bogus 'not recording'.
  Future<void> recoverInterruptedSave(Entry entry) async {
    if (_discardedSaves.remove(entry.id)) return;
    final path = entry.audioPath;
    if (path != null && _referencedElsewhere(path, entry.id)) return;
    final future = _recoverInterruptedSave(entry);
    _recovering = future;
    try {
      await future;
    } finally {
      if (identical(_recovering, future)) _recovering = null;
    }
  }

  Future<void> _recoverInterruptedSave(Entry entry) async {
    await _store.save(entry);
    if (!_recording && !_starting) _lastFinalized = entry;
    if (!_autoFinalized.isClosed) _autoFinalized.add(entry);
  }

  /// Auto-finalizes on a native interruption. Saves untranscribed, unlike a user
  /// stop: an interruption often means the app is backgrounding (and may be suspended
  /// within seconds), so the audio is persisted first and can be re-transcribed
  /// later. A no-audio interruption makes stop() throw [CaptureFailed] (nothing to
  /// save); a real save failure is surfaced on [autoFinalized] as an
  /// [EntrySaveFailed] carrying the entry, so a listener can [retrySave] it rather
  /// than orphan the audio this feature exists to protect.
  Future<void> _handleInterruption() async {
    if (!_recording) return;
    final future = _stopAndPersist(transcribe: false);
    _finalizing = future;
    _interruptionFinalize = future;
    try {
      final entry = await future;
      if (entry == null) return;
      // Stamp only while this finalize still owns the session: a new recording may
      // have started (clearing _finalizing), and its later double-stop contract
      // must not be broken by this stale entry. The emit still happens: the save
      // is real either way.
      if (identical(_finalizing, future)) _lastFinalized = entry;
      if (!_autoFinalized.isClosed) _autoFinalized.add(entry);
    } on CaptureFailed {
      // No audio was captured before the interruption; nothing to save.
    } catch (error, stack) {
      if (!_autoFinalized.isClosed) _autoFinalized.addError(error, stack);
    } finally {
      // In-flight only: the completed result lives in _lastFinalized.
      if (identical(_finalizing, future)) _finalizing = null;
      if (identical(_interruptionFinalize, future)) _interruptionFinalize = null;
    }
  }

  /// Deletes an entry and its kept audio file. The audio is the source of truth,
  /// so removing the record removes the recording with it - unless another entry
  /// references the same file, in which case only this record goes and the
  /// recording stays with its remaining owner (see [_referencedElsewhere]).
  Future<void> deleteEntry(Entry entry) async {
    final path = entry.audioPath;
    if (path != null && !_referencedElsewhere(path, entry.id)) {
      final File file;
      try {
        file = File(await _resolveAudioPath(path));
      } catch (error) {
        // A channel failure resolving the directory: nothing was deleted, so
        // surface the typed failure the retry contract advertises.
        throw EntryDeleteFailed(entry, error);
      }
      if (file.existsSync()) {
        try {
          await _deleteFile(file);
        } catch (error) {
          // If the file survived the failed delete, removing the record too would
          // orphan it and the reconcile sweep would resurrect the "deleted"
          // recording next launch. Keep the record so a retry removes both.
          if (file.existsSync()) throw EntryDeleteFailed(entry, error);
        }
      }
    }
    await _store.delete(entry.id);
  }

  /// Discards an entry's kept audio, keeping the record: peaks are captured
  /// first (best effort) so the waveform survives, the file is deleted, then
  /// the STORED entry is re-read and saved without its path. That fresh read
  /// has no await before the save, so a delete, rename or re-transcription
  /// landing mid-discard is never clobbered and a deleted entry is never
  /// resurrected as a transcript-only ghost. Returns false when nothing was
  /// discarded: the entry is gone, or the audio is still on disk and referenced
  /// (a later sweep retries). Never throws, since it runs detached behind saves.
  /// Bulk sweeps pass [notify] false and announce once at the end, so an
  /// N-entry purge costs the listeners one reload, not N, and pass [shared]
  /// ([_sharedAudioNames]) so the shared-file check below costs one journal pass
  /// for the whole sweep rather than one per entry. This acts only on the exact
  /// record-state it evaluated: [expectMissing] (set by [healDanglingAudio])
  /// bails the instant the file it was told is gone turns out to be back, and
  /// the final save bails if the path it resolved no longer matches the
  /// stored entry's path (an import adoption rewrote it mid-flight); either
  /// way this is a no-op, left for a later sweep to reconsider.
  Future<bool> _discardAudio(
    String entryId, {
    bool notify = true,
    Set<String>? shared,
    bool expectMissing = false,
  }) async {
    try {
      final stored = _store.read(entryId);
      if (stored == null) return false;
      final path = stored.audioPath;
      if (path == null) return true;
      final file = File(await _resolveAudioPath(path));
      if (expectMissing && file.existsSync()) return false;
      // A file another entry also references outlives this discard, path and
      // all: stripping the path here would cost this entry its playback while
      // freeing nothing. Only checked while the file is actually there, so a
      // heal (whose file is already gone) still repairs both records.
      if (file.existsSync() &&
          (shared?.contains(baseName(path)) ?? _referencedElsewhere(path, entryId))) {
        return false;
      }
      if (stored.peaks == null && _peaksReader != null) {
        try {
          await saveEntryPeaks(stored, await _peaksReader(file.path));
        } catch (_) {
          // The wave is cosmetic; losing it never blocks reclaiming the space.
        }
      }
      if (file.existsSync()) {
        try {
          await _deleteFile(file);
        } catch (_) {
          // Same rule as deleteEntry: while the file survives, the path stays,
          // or the reconcile sweep would resurrect the audio as a new entry.
          if (file.existsSync()) return false;
        }
      }
      final fresh = _store.read(entryId);
      if (fresh == null || fresh.audioPath == null) return true;
      if (fresh.audioPath != path) return false;
      await _store.save(fresh.withoutAudio());
      // Detached mutation: without this, an open screen keeps offering the
      // player and re-transcribe for audio that no longer exists.
      if (notify) _notifyEntriesChanged();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Finishes discards a kill interrupted: a transcribed entry whose audio
  /// file is ALREADY gone but whose record still points at it (the window
  /// between [_discardAudio]'s file delete and its save). Runs at launch in
  /// both keep modes, since the file's absence is a fact either way. Never
  /// deletes a file, so it can never destroy kept history; bulk reclaim stays
  /// [purgeTranscribedAudio] behind the Cache screen's confirm. Untranscribed
  /// records with missing audio are left alone: their words are gone, and a
  /// visibly broken entry the user can delete beats a silent empty one. Gated
  /// on [_unreferencedByDesign], the same predicate [reconcileOrphans] obeys:
  /// an adoption mid-restore can put a file back under a path this sweep
  /// already decided was gone, making "the file is absent" a stale fact.
  Future<int> healDanglingAudio() async {
    if (_unreferencedByDesign) return 0;
    var healed = 0;
    final shared = _sharedAudioNames();
    for (final entry in _store.all()) {
      if (_unreferencedByDesign) break;
      try {
        final path = entry.audioPath;
        if (path == null || entry.transcript == null) continue;
        // exists(), not existsSync(): on the common path where nothing needs
        // healing this is the loop's only await that leaves the microtask queue
        // (the recordings dir is memoized, and the discard below runs for the
        // rare broken record), and Dart drains microtasks before the next
        // frame, so a sync stat would run the whole sweep inside one frame.
        if (await File(await _resolveAudioPath(path)).exists()) continue;
        if (await _discardAudio(entry.id, notify: false, shared: shared, expectMissing: true)) {
          healed++;
        }
      } catch (_) {
        // Best effort per entry, like the reconcile sweep; next launch retries.
      }
    }
    if (healed > 0) _notifyEntriesChanged();
    return healed;
  }

  /// What the kept recordings occupy on disk, for the Cache surface. A
  /// read-only sweep over the entries: files that vanished or cannot be
  /// statted are skipped entirely (counted in neither bytes nor counts).
  /// Reclaimable means the entry is transcribed, so [purgeTranscribedAudio]
  /// would free it.
  Future<AudioUsage> audioUsage() async {
    var totalBytes = 0, totalCount = 0, reclaimableBytes = 0, reclaimableCount = 0;
    for (final entry in _store.all()) {
      final path = entry.audioPath;
      if (path == null) continue;
      int bytes;
      try {
        bytes = await File(await _resolveAudioPath(path)).length();
      } catch (_) {
        continue;
      }
      totalBytes += bytes;
      totalCount++;
      if (entry.transcript != null) {
        reclaimableBytes += bytes;
        reclaimableCount++;
      }
    }
    return AudioUsage(
      totalBytes: totalBytes,
      totalCount: totalCount,
      reclaimableBytes: reclaimableBytes,
      reclaimableCount: reclaimableCount,
    );
  }

  /// Reclaims the audio of every already-transcribed entry, leaving the records
  /// transcript-only. EXPLICIT action only, behind the Cache screen's confirm:
  /// this destroys kept history, so no automatic path may call it (the launch
  /// sweep runs [healDanglingAudio], which never deletes a file). Per-entry
  /// failures are skipped (the next run retries); the returned count is
  /// approximate under concurrency (an entry another path just discarded may
  /// still count). An overlapping call returns 0.
  Future<int> purgeTranscribedAudio() async {
    if (_purging) return 0;
    _purging = true;
    try {
      var discarded = 0;
      final shared = _sharedAudioNames();
      for (final entry in _store.all()) {
        if (entry.transcript == null || entry.audioPath == null) continue;
        if (await _discardAudio(entry.id, notify: false, shared: shared)) discarded++;
      }
      if (discarded > 0) _notifyEntriesChanged();
      return discarded;
    } finally {
      _purging = false;
    }
  }

  /// Re-transcribes a kept recording, optionally with a different engine. This is
  /// the whole payoff of keeping raw audio: a sharper engine re-reads your history
  /// with no re-recording and no network. Unlike stop, a failure here throws.
  /// The language resolves through the entry's own chain: an explicit [localeId],
  /// else the transcript's locale, else the RECORDING-time locale, else the app
  /// default. So a default change never silently re-languages an entry, and an
  /// untranscribed take keeps the language it was spoken in. (Note the pin: an
  /// entry first transcribed in the WRONG locale keeps that locale on re-runs
  /// until a caller passes [localeId] explicitly.) The landing is a change
  /// like any other: the words it replaces stay in the entry's history.
  Future<Entry> retranscribe(Entry entry, {TranscriptionEngine? using, String? localeId}) async {
    final engine = using ?? _engine;
    // Captured beside the engine: an engine switch landing during the awaits
    // below must not pair this engine with the other engine's resolution.
    final serviceLocaleId = this.localeId;
    // The one rule holds here too: re-transcription must stay on-device.
    if (!engine.onDeviceOnly) {
      throw ArgumentError('retranscribe requires an on-device engine: ${engine.id}');
    }
    final path = entry.audioPath;
    if (path == null) {
      throw StateError('entry ${entry.id} is transcript-only, nothing to retranscribe');
    }
    final audioFile = File(await _resolveAudioPath(path));
    // A mixed-language take re-transcribes span by span, rebuilding the mix,
    // UNLESS the caller chose a language explicitly: the user's correction
    // flattens the whole take into that one language on purpose.
    final spans = entry.languageSpans;
    final Transcript transcript;
    if (localeId == null && spans != null && spans.length > 1) {
      transcript = await _segmentedBatch(engine, audioFile, entry.duration, [
        for (final span in spans) (startMs: span.startMs, tag: span.localeId),
      ]);
    } else {
      final locale = localeId ?? entry.effectiveLocaleId ?? serviceLocaleId;
      transcript = await _batch(engine, audioFile, entry.duration, localeId: locale);
    }
    // A first-use model install may have piggybacked on this pass.
    _notifyModelStateChanged();
    // The batch pass can run minutes; the user may have deleted the entry or
    // renamed it meanwhile. Never resurrect a deleted entry as a ghost, and
    // never clobber a fresher title: the transcript is applied to the STORED
    // entry, not the caller's stale copy. Safe against an interleaved delete
    // because the store's visible state mutates synchronously (see EntryStore).
    final stored = _store.read(entry.id);
    if (stored == null) {
      throw StateError('entry ${entry.id} was deleted during retranscribe');
    }
    // Discard only on the FIRST landing that heard words: that is the keep-off
    // deferral completing (a failed, interrupted, or empty first pass finally
    // landing something). A repeat re-transcription never deletes; bulk
    // reclaim is explicit only.
    final hadWords = stored.transcript != null && stored.transcript!.fullText.trim().isNotEmpty;
    final retranscribed = stored.withTranscript(transcript);
    // The words this landing replaces go into history; a first transcription
    // of an untouched entry replaces nothing and pushes nothing. Two more
    // silences: a landing that heard NOTHING pushes no empty head, and a
    // re-run that heard the same words again (whitespace aside, like the
    // diff reads them) has no change to record - the head already is that
    // revision.
    final base = _revisionsWithBase(stored);
    final heardNothing = transcript.fullText.trim().isEmpty;
    final skipPush = base.isEmpty || heardNothing || sameWords(base.last.text, transcript.fullText);
    final Entry updated;
    if (!skipPush) {
      updated = retranscribed.withRevisions([...base, Revision.ofTranscript(transcript)]);
    } else if (heardNothing && base.isNotEmpty) {
      // The empty landing still replaced the transcript; on a pristine entry
      // the base must materialize with it, or the words it buried are gone
      // from display and history both.
      updated = retranscribed.withRevisions(base);
    } else {
      updated = retranscribed;
    }
    await _store.save(updated);
    if (!hadWords && !heardNothing && !_keepAudio()) {
      await _discardAudio(entry.id);
      return _store.read(entry.id) ?? updated;
    }
    return updated;
  }

  /// Renames an entry; a null or blank [title] clears it back to untitled. The
  /// title is applied to the STORED entry, not the caller's copy, so a rename
  /// racing a re-transcription cannot clobber the fresher transcript. Throws
  /// [StateError] when the entry was deleted meanwhile (same ghost rule as
  /// [retranscribe]); safe against an interleaved delete because the store's
  /// visible state mutates synchronously (see EntryStore).
  Future<Entry> renameEntry(Entry entry, String? title) async {
    final trimmed = title?.trim();
    final normalized = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    final stored = _store.read(entry.id);
    if (stored == null) {
      throw StateError('entry ${entry.id} was deleted during rename');
    }
    final updated = stored.withTitle(normalized);
    await _store.save(updated);
    return updated;
  }

  /// Applies a hand edit of the transcript text to the STORED entry, pushed
  /// as a revision onto its history. A blank [text], or what the entry reads
  /// as typed back, writes nothing: restoring is History's job, not a side
  /// effect of the field. Hand whitespace IS a change (a typed paragraph
  /// break must never be silently swallowed); only ENGINE landings compare
  /// whitespace-blind, since their spacing variance is noise. Throws
  /// [StateError] when the entry was deleted meanwhile (same ghost rule as
  /// [retranscribe]); safe against an interleaved delete because the store's
  /// visible state mutates synchronously (see EntryStore).
  Future<Entry> editTranscript(Entry entry, String text) async {
    final trimmed = text.trim();
    final stored = _store.read(entry.id);
    if (stored == null) {
      throw StateError('entry ${entry.id} was deleted during edit');
    }
    if (trimmed.isEmpty || trimmed == stored.readableText?.trim()) {
      return stored;
    }
    final updated = stored.withRevisions([
      ..._revisionsWithBase(stored),
      Revision(text: trimmed, at: _clock()),
    ]);
    await _store.save(updated);
    return updated;
  }

  /// Restores [revision] as the new head by pushing a COPY stamped now, its
  /// origin kept: history only grows, so a restore can itself be reverted.
  /// Restoring what the entry already reads as writes nothing; the compare
  /// is whitespace-blind only between engine text on BOTH sides. A hand
  /// revision's whitespace, or a hand head's, is a deliberate change, so
  /// restoring across it must push - undoing a typed paragraph break by
  /// tapping the engine base is exactly the restore that matters. Same
  /// stored entry and ghost rules as [editTranscript].
  Future<Entry> restoreRevision(Entry entry, Revision revision) async {
    final stored = _store.read(entry.id);
    if (stored == null) {
      throw StateError('entry ${entry.id} was deleted during restore');
    }
    final reads = stored.readableText;
    final blind = !revision.isHand && !(stored.head?.isHand ?? false);
    final already = blind
        ? sameWords(revision.text, reads ?? '')
        : revision.text.trim() == reads?.trim();
    if (already) return stored;
    final updated = stored.withRevisions([
      ..._revisionsWithBase(stored),
      Revision(
        text: revision.text,
        at: _clock(),
        engineId: revision.engineId,
        localeId: revision.localeId,
      ),
    ]);
    await _store.save(updated);
    return updated;
  }

  /// Removes [revision] from the entry's history: the one place the stack
  /// shrinks, and only ever by the user's own hand. Deleting the head makes
  /// the revision under it what the entry reads as. The LAST remaining
  /// revision is untouchable: what the entry reads as must always have a
  /// revision to stand on once it has any. A revision no longer in the
  /// stored stack is a no-op. Same stored entry and ghost rules as
  /// [editTranscript].
  Future<Entry> deleteRevision(Entry entry, Revision revision) async {
    final stored = _store.read(entry.id);
    if (stored == null) {
      throw StateError('entry ${entry.id} was deleted during revision delete');
    }
    final revisions = stored.revisions;
    final index = revisions?.indexOf(revision) ?? -1;
    if (revisions == null || index < 0) return stored;
    if (revisions.length == 1) return stored;
    final updated = stored.withRevisions([...revisions]..removeAt(index));
    await _store.save(updated);
    return updated;
  }

  /// The stored stack, materialized under a FIRST change: the engine base is
  /// laid down so history always starts at the words the engine wrote. A
  /// silent or absent transcript lays no base, since there were no words to
  /// remember.
  List<Revision> _revisionsWithBase(Entry stored) {
    final existing = stored.revisions;
    if (existing != null && existing.isNotEmpty) return existing;
    final transcript = stored.transcript;
    if (transcript == null || transcript.fullText.trim().isEmpty) return const [];
    return [Revision.ofTranscript(transcript)];
  }

  /// The absolute path of an entry's kept audio, for playback. The service owns
  /// where entry audio lives, so a caller (e.g. a player) resolves through here
  /// rather than reaching into storage itself. Throws [StateError] for a
  /// transcript-only entry; callers gate on [Entry.hasAudio].
  Future<String> resolveAudioPath(Entry entry) {
    final path = entry.audioPath;
    if (path == null) {
      throw StateError('entry ${entry.id} is transcript-only, no audio to resolve');
    }
    return _resolveAudioPath(path);
  }

  /// Persists a computed amplitude envelope onto the STORED entry (quantized
  /// to 0..255), so later opens skip the full-file decode. Applied to the
  /// stored record, never the caller's copy, and only once: a no-op when the
  /// entry was deleted meanwhile or already carries a shape. Best effort; a
  /// failed write just means the next open computes again.
  Future<void> saveEntryPeaks(Entry entry, List<double> peaks) async {
    if (peaks.isEmpty) return;
    final stored = _store.read(entry.id);
    if (stored == null || stored.peaks != null) return;
    final quantized = [for (final v in peaks) (v.clamp(0.0, 1.0) * 255).round()];
    try {
      await _store.save(stored.withPeaks(quantized));
    } catch (_) {
      // The envelope is derived data; losing the write costs one re-decode.
    }
  }

  /// Save-time backfill for a NEW entry: read the shape once and persist it.
  Future<void> _backfillPeaks(Entry entry) async {
    final reader = _peaksReader;
    final audioPath = entry.audioPath;
    if (reader == null || entry.peaks != null || audioPath == null) return;
    try {
      final path = await _resolveAudioPath(audioPath);
      await saveEntryPeaks(entry, await reader(path));
    } catch (_) {
      // Unreadable now (or mid-teardown): the first open backfills instead.
    }
  }

  /// The recordings directory, fetched once: it is stable for the process
  /// lifetime (the container only moves between launches), and the launch
  /// sweeps resolve O(entries) paths, which would otherwise be one channel
  /// round trip each.
  String? _recordingsDir;

  /// Resolves a stored audio reference to an absolute path. Real entries store a
  /// bare filename, stable across a backup/restore that would move the app's
  /// container; an already-absolute path (tests, legacy) is returned unchanged.
  Future<String> _resolveAudioPath(String stored) async {
    if (stored.startsWith('/')) return stored;
    var dir = _recordingsDir ?? await _recorder.recordingsDirectory();
    if (dir.endsWith('/')) dir = dir.substring(0, dir.length - 1);
    _recordingsDir = dir;
    return '$dir/$stored';
  }

  Future<Transcript> _batch(
    TranscriptionEngine engine,
    File file,
    Duration duration, {
    String? localeId,
    Duration? start,
    Duration? end,
  }) {
    // Scale the timeout by audio length so a long entry is not cut off, while still
    // bounding a hung native call.
    final timeout = _batchTimeout + duration * 2;
    return engine
        .transcribeFile(file, localeId: localeId ?? this.localeId, start: start, end: end)
        .timeout(
          timeout,
          onTimeout: () {
            // The Dart side is giving up; tell the engine so the native task does not
            // keep holding the recognizer for work nobody will read. CancellableBatchEngine
            // does not extend TranscriptionEngine, so `is` alone cannot promote; the cast
            // makes the member visible.
            if (engine is CancellableBatchEngine) {
              unawaited((engine as CancellableBatchEngine).cancelBatches());
            }
            throw const TranscriptionFailed('transcription timed out');
          },
        );
  }

  /// Batches a mixed-language take span by span and merges the results: texts
  /// joined with a `[fr]`-style marker at each switch, segment timings offset
  /// to file time, the first span's language as the transcript's. Any span
  /// failing (an engine that cannot slice, pre-26) falls the WHOLE take back
  /// to one flattened pass in the first span's language: a flattened
  /// transcript beats an untranscribed entry, and the persisted spans let a
  /// re-transcription rebuild the mix on a capable engine later.
  Future<Transcript> _segmentedBatch(
    TranscriptionEngine engine,
    File file,
    Duration duration,
    List<({int startMs, String tag})> spans,
  ) async {
    try {
      final parts = <Transcript>[];
      for (var i = 0; i < spans.length; i++) {
        final start = Duration(milliseconds: spans[i].startMs);
        final end = i + 1 < spans.length ? Duration(milliseconds: spans[i + 1].startMs) : null;
        final spanLength = (end ?? duration) - start;
        parts.add(
          await _batch(
            engine,
            file,
            spanLength.isNegative ? Duration.zero : spanLength,
            localeId: spans[i].tag,
            start: start,
            end: end,
          ),
        );
      }
      final buffer = StringBuffer();
      final segments = <TranscriptSegment>[];
      // The transcript's language is the first SPOKEN span's: a take whose
      // opening span held only silence is, effectively, the later language.
      String? firstSpokenTag;
      for (var i = 0; i < parts.length; i++) {
        final offset = Duration(milliseconds: spans[i].startMs);
        final text = parts[i].fullText.trim();
        if (text.isNotEmpty) firstSpokenTag ??= spans[i].tag;
        // A silent span earns neither text nor a marker; the first spoken
        // span earns no marker either (nothing before it to separate).
        if (text.isNotEmpty && buffer.isEmpty) {
          buffer.write(text);
        } else if (text.isNotEmpty) {
          final marker = '[${spans[i].tag.split('-').first}]';
          buffer.write(' $marker $text');
          // The marker also rides as its own zero-length segment at the
          // switch instant: the transcript VIEW renders segments (not
          // fullText), so without this the reader would never see where the
          // language turned - and tapping it seeks to that moment.
          segments.add(TranscriptSegment(text: marker, start: offset, end: offset));
        }
        for (final segment in parts[i].segments) {
          segments.add(
            TranscriptSegment(
              text: segment.text,
              start: segment.start + offset,
              end: segment.end + offset,
              confidence: segment.confidence,
            ),
          );
        }
      }
      return Transcript(
        fullText: buffer.toString(),
        segments: segments,
        localeId: firstSpokenTag ?? spans.first.tag,
        engineId: engine.id,
        createdAt: _clock(),
      );
    } on TranscriptionException {
      return _batch(engine, file, duration, localeId: spans.first.tag);
    }
  }

  /// Recovers audio files in the recordings directory that no entry references:
  /// readable ones (an interruption finalized them but the app died before the
  /// record landed) become untranscribed entries; unreadable ones (an unfinalized
  /// header after a mid-recording kill) are deleted. Without this sweep such files
  /// would persist invisibly forever, undeletable by any UI, holding the user's
  /// voice after they believe it is gone. Skipped while a capture is live or
  /// finalizing, or an import is adopting (their files have no entry yet by
  /// design).
  ///
  /// Returns the number recovered, or null when the whole directory was not
  /// walked: a capture was live or starting, a finalize or an import had not yet
  /// saved its entry, another sweep already held the snapshot, or one of those
  /// began mid-walk. Null is not zero: the caller must rerun the sweep later,
  /// because whatever it did not reach stays invisible.
  Future<int?> reconcileOrphans() async {
    if (_recording || _starting || _reconciling || _unreferencedByDesign) return null;
    // Single-flight: the `referenced` set is snapshotted once, so two concurrent
    // sweeps could double-recover or double-delete the same file.
    _reconciling = true;
    try {
      final dirPath = await _recorder.recordingsDirectory();
      if (dirPath.isEmpty) return 0;
      final dir = Directory(dirPath);
      if (!dir.existsSync()) return 0;

      // Transcript-only entries reference no file and cannot anchor one.
      final referenced = _store
          .all()
          .map((e) => e.audioPath)
          .whereType<String>()
          .map((p) => p.split('/').last)
          .toSet();
      var recovered = 0;
      var complete = true;
      await for (final item in dir.list(followLinks: false)) {
        if (item is! File) continue;
        final name = item.uri.pathSegments.last;
        if (referenced.contains(name)) continue;
        // A capture may have started, or a finalize or an import may have
        // claimed one, while this sweep awaited; either file has no entry yet
        // and must not be touched. The `referenced` snapshot cannot know them.
        if (_recording || _starting || _unreferencedByDesign) {
          complete = false;
          break;
        }
        // The probe is inside the per-file try: it reaches the recorder, and a
        // CaptureFailed on one unreadable file must not abandon the rest.
        try {
          final duration = await _recorder.probeRecording(name);
          if (duration == null) {
            await item.delete();
          } else {
            await _store.save(
              Entry(
                id: _newId(),
                createdAt: item.statSync().modified,
                audioPath: name,
                duration: duration,
              ),
            );
            recovered++;
          }
        } catch (_) {
          // Best effort per file; the next sweep retries whatever failed.
        }
      }
      // Detached recovery: without this, a take recovered after home seeded
      // its list stays invisible until an unrelated reload.
      if (recovered > 0) _notifyEntriesChanged();
      return complete ? recovered : null;
    } finally {
      _reconciling = false;
    }
  }

  /// Finalizes an in-flight capture (untranscribed) and saves it, without tearing
  /// the service down. Wired to app termination ([AppLifecycleState.detached]):
  /// a terminate while recording would otherwise leave the file unfinalized, and
  /// the reconcile sweep deletes a file it cannot probe. No [autoFinalized] emit
  /// (this is not an interruption); on success the entry is reachable via
  /// [entries], and if even the retry fails the sweep recovers it next launch.
  /// A no-op when idle; never throws.
  Future<void> finalizeActiveCapture() async {
    if (!_recording) return;
    try {
      await _stopAndPersist(transcribe: false);
    } on EntrySaveFailed catch (e) {
      // Retry once instead of silently dropping the only handle to the recording.
      try {
        await retrySave(e.entry);
      } catch (_) {
        // The sweep recovers it next launch.
      }
    } catch (_) {
      // CaptureFailed etc.: nothing was captured.
    }
  }

  Future<void> dispose() async {
    // Never abandon a live capture: finalize and save it (untranscribed) first, or
    // the native session would keep running and the audio would never get a record.
    await finalizeActiveCapture();
    await _liveSub?.cancel();
    _liveSub = null;
    await _statusSub?.cancel();
    _statusSub = null;
    await _live.close();
    await _autoFinalized.close();
    await _modelStateChanged.close();
    await _entriesChanged.close();
  }

  static int _idSequence = 0;

  static String _defaultId() =>
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}-${_idSequence++}';
}

/// What kept recordings occupy on disk; see [TranscriptionService.audioUsage].
@immutable
final class AudioUsage {
  const AudioUsage({
    required this.totalBytes,
    required this.totalCount,
    required this.reclaimableBytes,
    required this.reclaimableCount,
  });

  final int totalBytes;
  final int totalCount;

  /// The share held by already-transcribed entries, the part a purge frees.
  final int reclaimableBytes;
  final int reclaimableCount;

  @override
  bool operator ==(Object other) =>
      other is AudioUsage &&
      other.totalBytes == totalBytes &&
      other.totalCount == totalCount &&
      other.reclaimableBytes == reclaimableBytes &&
      other.reclaimableCount == reclaimableCount;

  @override
  int get hashCode => Object.hash(totalBytes, totalCount, reclaimableBytes, reclaimableCount);
}

/// Persisting a finalized entry failed. Carries the [entry] (which already
/// references its kept audio) so the caller can [TranscriptionService.retrySave]
/// instead of losing the only handle to the recording. Under keep-audio off a
/// recovered save keeps its audio (the discard chains only behind a successful
/// first save); reclaiming it later is the Cache screen's explicit clear.
final class EntrySaveFailed implements Exception {
  const EntrySaveFailed(this.entry, this.cause);

  final Entry entry;
  final Object cause;

  @override
  String toString() => 'EntrySaveFailed(${entry.id}): $cause';
}

/// Deleting an entry's kept audio file failed and the file is still on disk, so
/// the record was NOT removed: dropping it would orphan the file and the
/// reconcile sweep would resurrect the "deleted" recording. Carries the [entry]
/// so a caller can retry [TranscriptionService.deleteEntry].
final class EntryDeleteFailed implements Exception {
  const EntryDeleteFailed(this.entry, this.cause);

  final Entry entry;
  final Object cause;

  @override
  String toString() => 'EntryDeleteFailed(${entry.id}): $cause';
}

/// One archive entry ready for adoption: the record (its [Entry.audioPath]
/// already the intended bare filename, or null for transcript-only) and the
/// temp-staged audio file to move in, when the archive carried one.
@immutable
final class StagedImportEntry {
  const StagedImportEntry({required this.entry, this.stagedAudio});

  final Entry entry;
  final File? stagedAudio;
}

/// What adopting an archive's entries actually did, for the import summary.
@immutable
final class AdoptResult {
  const AdoptResult({
    required this.added,
    required this.updated,
    required this.unchanged,
    required this.audioRestored,
  });

  final int added;
  final int updated;
  final int unchanged;
  final int audioRestored;

  @override
  bool operator ==(Object other) =>
      other is AdoptResult &&
      other.added == added &&
      other.updated == updated &&
      other.unchanged == unchanged &&
      other.audioRestored == audioRestored;

  @override
  int get hashCode => Object.hash(added, updated, unchanged, audioRestored);
}
