import 'dart:async';
import 'dart:io';

import 'package:opentranscribe/core/audio/audio_recorder.dart';
import 'package:opentranscribe/core/audio/recording.dart';
import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/services/entry_store.dart';
import 'package:opentranscribe/core/transcribe/transcript.dart';
import 'package:opentranscribe/core/transcribe/transcript_event.dart';
import 'package:opentranscribe/core/transcribe/transcription_engine.dart';
import 'package:opentranscribe/core/transcribe/transcription_exception.dart';

/// Drives the whole loop: capture -> transcribe -> persist, and re-transcribe a
/// kept recording with any engine. Engine-agnostic: it talks only to the
/// contracts, so swapping Apple Speech for whisper.cpp touches nothing here.
///
/// The settled transcript is always a batch pass over the kept file. That is the
/// source of truth: robust to a streaming engine's duration limits, identical to
/// what re-transcription would produce, and the reason raw audio is kept. A
/// streaming engine's live stream is used only for real-time UI ([liveEvents]); it
/// never decides the persisted transcript. If transcription fails, the recording is
/// kept untranscribed rather than lost, and can be re-transcribed later.
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
  }) : _clock = clock ?? DateTime.now,
       _newId = idGenerator ?? _defaultId,
       _deleteFile = fileDeleter ?? _deleteFileDefault {
    // The one rule, enforced in code: only on-device engines are allowed.
    if (!_engine.onDeviceOnly) {
      throw ArgumentError('TranscriptionService requires an on-device engine: ${_engine.id}');
    }
  }

  final AudioRecorder _recorder;
  final TranscriptionEngine _engine;
  final EntryStore _store;

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

  /// Reads an audio file's amplitude envelope (0..1), injected so the service
  /// can persist a new entry's shape at save time without owning a player.
  /// Null in tests that do not care; the detail screen then backfills on the
  /// first open instead.
  final Future<List<double>> Function(String path)? _peaksReader;

  final StreamController<TranscriptEvent> _live = StreamController<TranscriptEvent>.broadcast();
  final StreamController<Entry> _autoFinalized = StreamController<Entry>.broadcast();
  final StreamController<void> _modelStateChanged = StreamController<void>.broadcast();
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
  /// set on a user stop: a plain double-stop must keep throwing.
  Entry? _lastFinalized;

  /// The finalize in flight right now, so a stop that races it (arriving while the
  /// interruption is still saving) awaits the result instead of throwing.
  Future<Entry?>? _finalizing;

  /// The subset of [_finalizing] owned by an interruption, so a racing cancel can
  /// tell an auto-save (which its discard must undo) from a user stop's finalize
  /// (whose caller was promised the entry).
  Future<Entry?>? _interruptionFinalize;

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

  /// Whether the model is downloaded so transcription runs with no wait. An engine
  /// with no downloadable model is always ready. Kept with [checkAvailability]
  /// for the same future recording gate.
  Future<bool> isModelInstalled({String? localeId}) async {
    final engine = _engine;
    return engine is ManagedModelEngine
        ? engine.isModelInstalled(localeId: localeId ?? this.localeId)
        : true;
  }

  /// Fires after any path that may have changed a model's install state (a
  /// first-use install during transcription, an explicit install, a removal),
  /// so state layers re-read instead of polling or going stale.
  Stream<void> get modelStateChanged => _modelStateChanged.stream;

  void _notifyModelStateChanged() {
    if (!_modelStateChanged.isClosed) _modelStateChanged.add(null);
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
  /// downloadable model is ready for everything it supports.
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
    // No managed model: a supported language is ready as-is.
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
      _audioMsAccumulated = 0;
      _audioSegmentStart = _clock();
      // Cleared only after start succeeds: a failed start (mic busy during the very
      // call that interrupted us) must not lose the entry a prior finalize saved.
      _lastFinalized = null;
      _finalizing = null;
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
            if (generation != _liveGeneration || _live.isClosed) return;
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
    _liveSub = _subscribeLive(engine, tag);
  }

  /// Ends the capture and returns the saved entry. The intricate parts of the
  /// contract: a stop racing an interruption's auto-finalize returns the entry the
  /// interruption saved (in flight or completed) instead of throwing; a plain
  /// double-stop throws [StateError]; a persistence failure throws
  /// [EntrySaveFailed] carrying the entry, recoverable via [retrySave]; a
  /// transcription failure does NOT throw, the entry is saved untranscribed.
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
        if (entry != null) return entry;
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
    final last = _lastFinalized;
    if (last != null) return last;
    throw StateError('not recording');
  }

  /// Finalizes a capture exactly once: stops the recorder, optionally runs the batch
  /// pass, and persists the entry. The guard is a synchronous early-return followed
  /// by claiming `_recording = false`, with no await between, so a user stop racing an
  /// interruption cannot both proceed; the loser returns early. `_statusSub` is
  /// cancelled up front, before the first await, so a second `interrupted` event
  /// during `_recorder.stop()` cannot re-enter `_handleInterruption`. Returns null
  /// only when nothing was recording.
  Future<Entry?> _stopAndPersist({required bool transcribe}) async {
    if (!_recording) return _lastFinalized;
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
    _audioClockPause();
    await statusSub?.cancel();
    try {
      final recording = await _recorder.stop();
      // UI-only; released here (not after the batch) so the next take's live
      // session is not queued behind it. Re-awaited in the finally.
      unawaited(liveSub?.cancel());

      // The recording reference is a filename; resolve it to an absolute path to open
      // the file, but persist the reference verbatim so it survives a backup/restore.
      Transcript? transcript;
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
      // the whole file.
      unawaited(_backfillPeaks(entry));
      return entry;
    } finally {
      await liveSub?.cancel();
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
  /// an interruption that claimed the session first auto-saves it, and a
  /// discard must win over that save, so the finalize is awaited and its entry
  /// deleted. Throws [StateError] during an in-flight start, which cannot be
  /// safely undone from here.
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
          try {
            await deleteEntry(e.entry);
          } catch (_) {}
        } catch (_) {
          // Nothing was captured (CaptureFailed) or another failure: nothing kept.
        }
        if (saved != null) {
          if (identical(_lastFinalized, saved)) _lastFinalized = null;
          await deleteEntry(saved);
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
    await statusSub?.cancel();
    try {
      await _recorder.cancel();
    } on CaptureFailed {
      // Nothing captured or capture already dead: discarding was the goal.
    } finally {
      await liveSub?.cancel();
    }
  }

  /// Retries persisting an entry whose save failed ([EntrySaveFailed]). The entry
  /// already references its kept audio, so a successful retry fully recovers it.
  /// Pure: no side effects, so [dispose]/[finalizeActiveCapture] can use it
  /// during teardown without touching the controllers they are closing.
  Future<void> retrySave(Entry entry) => _store.save(entry);

  /// Recovers an interruption's auto-save after it failed and surfaced on
  /// [autoFinalized] as an [EntrySaveFailed]. Persists the entry, then
  /// re-announces it on [autoFinalized] as a normal event so list surfaces
  /// refresh. Sets [_lastFinalized] only while idle, so a take that started
  /// meanwhile keeps its own double-stop contract (a stale entry must never be
  /// handed to a new take's stop).
  Future<void> recoverInterruptedSave(Entry entry) async {
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
  /// so removing the record removes the recording with it.
  Future<void> deleteEntry(Entry entry) async {
    final file = File(await _resolveAudioPath(entry.audioPath));
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
    await _store.delete(entry.id);
  }

  /// Re-transcribes a kept recording, optionally with a different engine. This is
  /// the whole payoff of keeping raw audio: a sharper engine re-reads your history
  /// with no re-recording and no network. Unlike stop, a failure here throws.
  /// The language resolves through the entry's own chain: an explicit [localeId],
  /// else the transcript's locale, else the RECORDING-time locale, else the app
  /// default. So a default change never silently re-languages an entry, and an
  /// untranscribed take keeps the language it was spoken in. (Note the pin: an
  /// entry first transcribed in the WRONG locale keeps that locale on re-runs
  /// until a caller passes [localeId] explicitly.)
  Future<Entry> retranscribe(Entry entry, {TranscriptionEngine? using, String? localeId}) async {
    final engine = using ?? _engine;
    // The one rule holds here too: re-transcription must stay on-device.
    if (!engine.onDeviceOnly) {
      throw ArgumentError('retranscribe requires an on-device engine: ${engine.id}');
    }
    final audioFile = File(await _resolveAudioPath(entry.audioPath));
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
      final locale = localeId ?? entry.effectiveLocaleId ?? this.localeId;
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
    final updated = stored.withTranscript(transcript);
    await _store.save(updated);
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

  /// The absolute path of an entry's kept audio, for playback. The service owns
  /// where entry audio lives, so a caller (e.g. a player) resolves through here
  /// rather than reaching into storage itself.
  Future<String> resolveAudioPath(Entry entry) => _resolveAudioPath(entry.audioPath);

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
    if (reader == null || entry.peaks != null) return;
    try {
      final path = await _resolveAudioPath(entry.audioPath);
      await saveEntryPeaks(entry, await reader(path));
    } catch (_) {
      // Unreadable now (or mid-teardown): the first open backfills instead.
    }
  }

  /// Resolves a stored audio reference to an absolute path. Real entries store a
  /// bare filename, stable across a backup/restore that would move the app's
  /// container; an already-absolute path (tests, legacy) is returned unchanged.
  Future<String> _resolveAudioPath(String stored) async {
    if (stored.startsWith('/')) return stored;
    var dir = await _recorder.recordingsDirectory();
    if (dir.endsWith('/')) dir = dir.substring(0, dir.length - 1);
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
          onTimeout: () => throw const TranscriptionFailed('transcription timed out'),
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
  /// voice after they believe it is gone. Skipped while a capture is live (its
  /// in-progress file has no entry yet by design). Returns the number recovered.
  Future<int> reconcileOrphans() async {
    if (_recording || _starting || _reconciling) return 0;
    // Single-flight: the `referenced` set is snapshotted once, so two concurrent
    // sweeps could double-recover or double-delete the same file.
    _reconciling = true;
    try {
      final dirPath = await _recorder.recordingsDirectory();
      if (dirPath.isEmpty) return 0;
      final dir = Directory(dirPath);
      if (!dir.existsSync()) return 0;

      final referenced = _store.all().map((e) => e.audioPath.split('/').last).toSet();
      var recovered = 0;
      await for (final item in dir.list(followLinks: false)) {
        if (item is! File) continue;
        final name = item.uri.pathSegments.last;
        if (referenced.contains(name)) continue;
        // A capture may have started while this sweep awaited; its file has no
        // entry yet and must not be touched.
        if (_recording || _starting) break;
        final duration = await _recorder.probeRecording(name);
        try {
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
      return recovered;
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
  }

  static int _idSequence = 0;

  static String _defaultId() =>
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}-${_idSequence++}';
}

/// Persisting a finalized entry failed. Carries the [entry] (which already
/// references its kept audio) so the caller can [TranscriptionService.retrySave]
/// instead of losing the only handle to the recording.
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
