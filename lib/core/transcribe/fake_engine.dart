import 'dart:io';

import 'package:opentranscribe/core/transcribe/transcript.dart';
import 'package:opentranscribe/core/transcribe/transcript_event.dart';
import 'package:opentranscribe/core/transcribe/transcription_engine.dart';
import 'package:opentranscribe/core/transcribe/transcription_exception.dart';

Transcript _cannedTranscript(String text, String localeId, String engineId, DateTime at) =>
    Transcript(
      fullText: text,
      segments: [
        TranscriptSegment(text: text, start: Duration.zero, end: const Duration(seconds: 1)),
      ],
      localeId: localeId,
      engineId: engineId,
      createdAt: at.toUtc(),
    );

/// Deterministic streaming engine for tests and dev harnesses. Its live stream
/// replays [cannedText] as growing partials (for UI), then a final event once
/// [stopSignal] completes. Its batch result is [batchText] (default [cannedText]),
/// so a test can prove the persisted transcript comes from batch, not live. Set
/// [failLive]/[failBatch] to exercise the failure paths.
class FakeStreamingEngine implements StreamingTranscriptionEngine {
  FakeStreamingEngine({
    this.cannedText = 'the quick brown fox jumps over the lazy dog',
    this.batchText,
    this.stopSignal,
    this.failLive = false,
    this.failBatch = false,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final String cannedText;
  final String? batchText;
  final Future<void>? stopSignal;
  final bool failLive;
  final bool failBatch;
  final DateTime Function() _clock;

  @override
  String get id => 'fake.streaming';

  @override
  bool get onDeviceOnly => true;

  @override
  Future<Availability> checkAvailability({required String localeId}) async =>
      const Availability.available();

  @override
  Future<Transcript> transcribeFile(File audio, {required String localeId}) async {
    if (failBatch) throw const TranscriptionFailed('fake batch failure');
    return _cannedTranscript(batchText ?? cannedText, localeId, id, _clock());
  }

  @override
  Stream<TranscriptEvent> transcribeLive({required String localeId}) async* {
    final words = cannedText.split(' ');
    final buffer = StringBuffer();
    for (var i = 0; i < words.length; i++) {
      buffer.write(i == 0 ? words[i] : ' ${words[i]}');
      yield TranscriptEvent(text: buffer.toString(), isFinal: false);
    }
    if (failLive) {
      throw const TranscriptionFailed('fake live failure');
    }
    await (stopSignal ?? Future<void>.value());
    yield TranscriptEvent(text: cannedText, isFinal: true);
  }
}

/// Deterministic batch-only engine, the whisper.cpp-shaped double: it is NOT a
/// [StreamingTranscriptionEngine], so it exercises the batch path through the type
/// check, not just the capability flag. Set [failBatch] to fail transcription.
class FakeBatchEngine implements TranscriptionEngine {
  FakeBatchEngine({
    this.cannedText = 'batch transcript',
    this.failBatch = false,
    this.throwGeneric = false,
    this.delay,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final String cannedText;

  /// Throws a [TranscriptionFailed] (the mapped taxonomy).
  final bool failBatch;

  /// Throws a non-taxonomy error, to prove the service never orphans a recording.
  final bool throwGeneric;

  /// Delays the result, to exercise the batch timeout.
  final Duration? delay;

  final DateTime Function() _clock;

  @override
  String get id => 'fake.batch';

  @override
  bool get onDeviceOnly => true;

  @override
  Future<Availability> checkAvailability({required String localeId}) async =>
      const Availability.available();

  @override
  Future<Transcript> transcribeFile(File audio, {required String localeId}) async {
    if (delay != null) await Future<void>.delayed(delay!);
    if (throwGeneric) throw StateError('generic engine failure');
    if (failBatch) throw const TranscriptionFailed('fake batch failure');
    return _cannedTranscript(cannedText, localeId, id, _clock());
  }
}
