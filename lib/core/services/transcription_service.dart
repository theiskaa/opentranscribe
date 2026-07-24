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
    DateTime Function()? clock,
    String Function()? idGenerator,
  }) : _clock = clock ?? DateTime.now,
       _newId = idGenerator ?? _defaultId {
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

  final StreamController<TranscriptEvent> _live = StreamController<TranscriptEvent>.broadcast();
  final StreamController<Entry> _autoFinalized = StreamController<Entry>.broadcast();
  StreamSubscription<TranscriptEvent>? _liveSub;
  StreamSubscription<CaptureStatus>? _statusSub;
  bool _recording = false;
  bool _paused = false;

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
  Future<Availability> checkAvailability({String? localeId}) =>
      _engine.checkAvailability(localeId: localeId ?? this.localeId);

  /// Whether the model is downloaded so transcription runs with no wait. An engine
  /// with no downloadable model is always ready.
  Future<bool> isModelInstalled({String? localeId}) async {
    final engine = _engine;
    return engine is ManagedModelEngine
        ? engine.isModelInstalled(localeId: localeId ?? this.localeId)
        : true;
  }

  /// Downloads the model, streaming progress to completion. An engine with no
  /// downloadable model completes instantly.
  Stream<ModelInstallProgress> installModel({String? localeId}) {
    final engine = _engine;
    return engine is ManagedModelEngine
        ? engine.installModel(localeId: localeId ?? this.localeId)
        : Stream.value(const ModelInstallProgress(fraction: 1, done: true));
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
      if (engine is StreamingTranscriptionEngine) {
        _liveSub = engine
            .transcribeLive(localeId: _sessionLocaleId ?? localeId)
            .listen(
              (event) {
                if (!_live.isClosed) _live.add(event);
              },
              onError: (Object error, StackTrace stack) {
                if (!_live.isClosed) _live.addError(error, stack);
              },
              cancelOnError: false,
            );
      }
    } finally {
      _starting = false;
    }
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
    await statusSub?.cancel();
    try {
      final recording = await _recorder.stop();

      // The recording reference is a filename; resolve it to an absolute path to open
      // the file, but persist the reference verbatim so it survives a backup/restore.
      Transcript? transcript;
      if (transcribe) {
        try {
          final audioFile = File(await _resolveAudioPath(recording.path));
          transcript = await _batch(
            _engine,
            audioFile,
            recording.duration,
            localeId: sessionLocale,
          );
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
      );
      try {
        await _store.save(entry);
      } catch (error) {
        // A failed save is the one real hole in "audio never orphaned": the file is
        // finalized but no record points at it. Throw the entry with the failure so
        // the caller can retry via [retrySave] instead of losing the reference.
        throw EntrySaveFailed(entry, error);
      }
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
    if (_recording) _paused = true;
  }

  /// Resumes a paused capture into the same recording. Throws [StateError] when
  /// not paused; a recorder failure propagates and leaves the session paused,
  /// still stoppable and cancellable.
  Future<void> resumeRecording() async {
    if (!_recording || !_paused) {
      throw StateError(_recording ? 'not paused' : 'not recording');
    }
    await _recorder.resume();
    if (_recording) _paused = false;
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
        } catch (_) {
          // Nothing was captured or the save failed: nothing kept to discard.
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
  Future<void> retrySave(Entry entry) => _store.save(entry);

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
        await file.delete();
      } catch (_) {
        // Metadata removal below still proceeds; a stray file is not fatal.
      }
    }
    await _store.delete(entry.id);
  }

  /// Re-transcribes a kept recording, optionally with a different engine. This is
  /// the whole payoff of keeping raw audio: a sharper engine re-reads your history
  /// with no re-recording and no network. Unlike stop, a failure here throws.
  /// Defaults to the entry's original transcript locale, so an app-language change
  /// does not silently re-read old entries in the wrong language. (Note the pin:
  /// an entry first transcribed in the WRONG locale keeps that locale on re-runs
  /// until a caller passes [localeId] explicitly.)
  Future<Entry> retranscribe(Entry entry, {TranscriptionEngine? using, String? localeId}) async {
    final engine = using ?? _engine;
    // The one rule holds here too: re-transcription must stay on-device.
    if (!engine.onDeviceOnly) {
      throw ArgumentError('retranscribe requires an on-device engine: ${engine.id}');
    }
    final audioFile = File(await _resolveAudioPath(entry.audioPath));
    final locale = localeId ?? entry.transcript?.localeId ?? this.localeId;
    final transcript = await _batch(engine, audioFile, entry.duration, localeId: locale);
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
  }) {
    // Scale the timeout by audio length so a long entry is not cut off, while still
    // bounding a hung native call.
    final timeout = _batchTimeout + duration * 2;
    return engine
        .transcribeFile(file, localeId: localeId ?? this.localeId)
        .timeout(
          timeout,
          onTimeout: () => throw const TranscriptionFailed('transcription timed out'),
        );
  }

  /// Recovers audio files in the recordings directory that no entry references:
  /// readable ones (an interruption finalized them but the app died before the
  /// record landed) become untranscribed entries; unreadable ones (an unfinalized
  /// header after a mid-recording kill) are deleted. Without this sweep such files
  /// would persist invisibly forever, undeletable by any UI, holding the user's
  /// voice after they believe it is gone. Skipped while a capture is live (its
  /// in-progress file has no entry yet by design). Returns the number recovered.
  Future<int> reconcileOrphans() async {
    if (_recording || _starting) return 0;
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
      // A capture may have started while this sweep awaited; its file has no entry
      // yet and must not be touched.
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
  }

  Future<void> dispose() async {
    // Never abandon a live capture: finalize and save it (untranscribed) first, or
    // the native session would keep running and the audio would never get a record.
    // No autoFinalized emit here (dispose is not an interruption, and the controller
    // is about to close). On success the entry is reachable via entries(); if even
    // the retry below fails, the reconcile sweep recovers the file next launch.
    if (_recording) {
      try {
        await _stopAndPersist(transcribe: false);
      } on EntrySaveFailed catch (e) {
        // The typed error would vanish with the closing controller; retry once
        // instead of silently dropping the only handle to the recording.
        try {
          await retrySave(e.entry);
        } catch (_) {
          // The sweep recovers it next launch.
        }
      } catch (_) {
        // CaptureFailed etc.: nothing was captured.
      }
    }
    await _liveSub?.cancel();
    _liveSub = null;
    await _statusSub?.cancel();
    _statusSub = null;
    await _live.close();
    await _autoFinalized.close();
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
