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
      createdAt: at,
    );

/// Deterministic streaming engine for tests and dev harnesses, shaped like the real
/// Apple engine: streaming AND model-managed. Its live stream replays [cannedText]
/// as growing partials (for UI), then a final event (with a timed segment, like the
/// real final) once [stopSignal] completes. Its batch result is [batchText] (default
/// [cannedText]), so a test can prove the persisted transcript comes from batch, not
/// live. Set [failLive]/[failBatch] to exercise the failure paths.
class FakeStreamingEngine implements StreamingTranscriptionEngine, ManagedModelEngine {
  FakeStreamingEngine({
    this.cannedText = 'the quick brown fox jumps over the lazy dog',
    this.batchText,
    this.stopSignal,
    this.failLive = false,
    this.failBatch = false,
    this.availability = const Availability.available(),
    this.supportedLocaleTags = const ['en-US'],
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final String cannedText;
  final String? batchText;
  final Future<void>? stopSignal;
  final bool failLive;
  final bool failBatch;
  final Availability availability;
  final List<String> supportedLocaleTags;
  final DateTime Function() _clock;

  @override
  String get id => 'fake.streaming';

  @override
  Future<List<String>> supportedLocales() async => supportedLocaleTags;

  @override
  bool get onDeviceOnly => true;

  @override
  Future<Availability> checkAvailability({required String localeId}) async => availability;

  @override
  Future<bool> isModelInstalled({required String localeId}) async => true;

  @override
  Stream<ModelInstallProgress> installModel({required String localeId}) =>
      Stream.value(const ModelInstallProgress(fraction: 1, done: true));

  @override
  Future<Transcript> transcribeFile(File audio, {required String localeId}) async {
    if (failBatch) throw const TranscriptionFailed('fake batch failure');
    return _cannedTranscript(batchText ?? cannedText, localeId, id, _clock());
  }

  /// The locale the most recent [transcribeLive] was asked for, for assertions.
  String? lastLiveLocaleId;

  @override
  Stream<TranscriptEvent> transcribeLive({required String localeId}) async* {
    lastLiveLocaleId = localeId;
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
    yield TranscriptEvent(
      text: cannedText,
      isFinal: true,
      segments: [
        TranscriptSegment(text: cannedText, start: Duration.zero, end: const Duration(seconds: 1)),
      ],
    );
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
    this.supportedLocaleTags = const ['en-US'],
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final String cannedText;

  /// The picker list this fake reports.
  final List<String> supportedLocaleTags;

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
  Future<List<String>> supportedLocales() async => supportedLocaleTags;

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

/// A batch engine that also manages a downloadable model, the double for isolating
/// the [ManagedModelEngine] path. [installed] seeds [isModelInstalled] and flips to
/// true once [installModel] completes (like the real engine); [installModel] replays
/// [installSteps] fractions then a done event, or throws when [failInstall] is set.
class FakeManagedEngine implements ManagedModelEngine {
  FakeManagedEngine({
    this.cannedText = 'batch transcript',
    this.installed = false,
    this.installSteps = const [0.5],
    this.failInstall = false,
    this.availability = const Availability.available(),
    this.supportedLocaleTags = const ['en-US'],
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final String cannedText;
  final List<String> supportedLocaleTags;
  bool installed;
  // Mutable: a test flips install behavior after construction.
  List<double> installSteps;
  bool failInstall;
  final Availability availability;
  final DateTime Function() _clock;

  @override
  String get id => 'fake.managed';

  @override
  Future<List<String>> supportedLocales() async => supportedLocaleTags;

  @override
  bool get onDeviceOnly => true;

  @override
  Future<Availability> checkAvailability({required String localeId}) async => availability;

  @override
  Future<bool> isModelInstalled({required String localeId}) async => installed;

  @override
  Stream<ModelInstallProgress> installModel({required String localeId}) async* {
    if (failInstall) throw const ModelInstallFailed('fake install failure');
    for (final fraction in installSteps) {
      yield ModelInstallProgress(fraction: fraction, done: false);
    }
    installed = true;
    yield const ModelInstallProgress(fraction: 1, done: true);
  }

  @override
  Future<Transcript> transcribeFile(File audio, {required String localeId}) async =>
      _cannedTranscript(cannedText, localeId, id, _clock());
}
