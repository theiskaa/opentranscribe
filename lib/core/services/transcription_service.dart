// ignore_for_file: prefer_initializing_formals
// The injected collaborators are private (a service coordinates them, it does not
// expose them), and sibling params carry defaults, so initializing formals do not
// apply here.

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
    required AudioRecorder recorder,
    required TranscriptionEngine engine,
    required EntryStore store,
    String localeId = 'en-US',
    Duration batchTimeout = const Duration(minutes: 2),
    DateTime Function()? clock,
    String Function()? idGenerator,
  }) : _recorder = recorder,
       _engine = engine,
       _store = store,
       _localeId = localeId,
       _batchTimeout = batchTimeout,
       _clock = clock ?? DateTime.now,
       _newId = idGenerator ?? _defaultId {
    // The one rule, enforced in code: only on-device engines are allowed.
    if (!engine.onDeviceOnly) {
      throw ArgumentError('TranscriptionService requires an on-device engine: ${engine.id}');
    }
  }

  final AudioRecorder _recorder;
  final TranscriptionEngine _engine;
  final EntryStore _store;
  final String _localeId;
  final Duration _batchTimeout;
  final DateTime Function() _clock;
  final String Function() _newId;

  final StreamController<TranscriptEvent> _live = StreamController<TranscriptEvent>.broadcast();
  StreamSubscription<TranscriptEvent>? _liveSub;
  bool _recording = false;

  /// Live partial/final events while recording, for real-time UI. Errors on the
  /// underlying live stream are forwarded here; they do not affect the persisted
  /// transcript, which comes from the batch pass on stop.
  Stream<TranscriptEvent> get liveEvents => _live.stream;

  /// Capture lifecycle (interruptions, stop) surfaced from the recorder.
  Stream<CaptureStatus> get captureStatus => _recorder.status;

  bool get isRecording => _recording;

  /// All saved entries, newest first. The store is the service's private detail;
  /// callers read and mutate entries only through the service, so the entry
  /// lifecycle (audio file + record) has one owner.
  List<Entry> entries() => _store.all();

  Future<void> startRecording() async {
    if (_recording) {
      throw StateError('already recording');
    }
    final permission = await _recorder.ensurePermission();
    if (permission != PermissionStatus.granted) {
      throw const PermissionDenied('microphone permission not granted');
    }
    await _recorder.start();
    _recording = true;

    final engine = _engine;
    // The type is the source of truth for streaming; there is no separate flag.
    if (engine is StreamingTranscriptionEngine) {
      _liveSub = engine
          .transcribeLive(localeId: _localeId)
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
  }

  Future<Entry> stopRecording() async {
    if (!_recording) {
      throw StateError('not recording');
    }
    try {
      final recording = await _recorder.stop();

      // The settled transcript is a batch pass over the kept file.
      Transcript? transcript;
      try {
        transcript = await _batch(_engine, File(recording.path), recording.duration);
      } catch (_) {
        // Any failure keeps the recording untranscribed rather than losing it; it
        // can be re-transcribed later. Never let a transcription error orphan audio.
        transcript = null;
      }

      final entry = Entry(
        id: _newId(),
        createdAt: _clock().toUtc(),
        audioPath: recording.path,
        duration: recording.duration,
        transcript: transcript,
      );
      await _store.save(entry);
      return entry;
    } finally {
      _recording = false;
      await _liveSub?.cancel();
      _liveSub = null;
    }
  }

  /// Deletes an entry and its kept audio file. The audio is the source of truth,
  /// so removing the record removes the recording with it.
  Future<void> deleteEntry(Entry entry) async {
    final file = File(entry.audioPath);
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
  Future<Entry> retranscribe(Entry entry, {TranscriptionEngine? using}) async {
    final engine = using ?? _engine;
    // The one rule holds here too: re-transcription must stay on-device.
    if (!engine.onDeviceOnly) {
      throw ArgumentError('retranscribe requires an on-device engine: ${engine.id}');
    }
    final transcript = await _batch(engine, File(entry.audioPath), entry.duration);
    final updated = entry.withTranscript(transcript);
    await _store.save(updated);
    return updated;
  }

  Future<Transcript> _batch(TranscriptionEngine engine, File file, Duration duration) {
    // Scale the timeout by audio length so a long entry is not cut off, while still
    // bounding a hung native call.
    final timeout = _batchTimeout + duration * 2;
    return engine
        .transcribeFile(file, localeId: _localeId)
        .timeout(
          timeout,
          onTimeout: () => throw const TranscriptionFailed('transcription timed out'),
        );
  }

  Future<void> dispose() async {
    await _liveSub?.cancel();
    _liveSub = null;
    await _live.close();
  }

  static int _idSequence = 0;

  static String _defaultId() =>
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(16)}-${_idSequence++}';
}
