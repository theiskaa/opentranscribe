import 'dart:async';
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
class FakeStreamingEngine
    implements StreamingTranscriptionEngine, ManagedModelEngine, CancellableBatchEngine {
  FakeStreamingEngine({
    this.cannedText = 'the quick brown fox jumps over the lazy dog',
    this.batchText,
    this.stopSignal,
    this.failLive = false,
    this.failBatch = false,
    this.liveNoFinal = false,
    this.batchDelay,
    this.availability = const Availability.available(),
    this.throwOnCheckAvailability = false,
    this.supportedLocaleTags = const ['en-US'],
    List<String>? installedLocaleTags,
    this.maxReservedLocales = 3,
    DateTime Function()? clock,
  }) : installedLocaleTags = List.of(installedLocaleTags ?? supportedLocaleTags),
       _clock = clock ?? DateTime.now;

  final String cannedText;
  final String? batchText;
  final Future<void>? stopSignal;
  final bool failLive;
  final bool failBatch;

  /// When true, the success path emits its partials then closes on [stopSignal]
  /// WITHOUT a final event, mirroring an analyzer session that only ever
  /// partials. Proves the batch result, not the live text, is the saved truth.
  final bool liveNoFinal;

  /// Delays [transcribeFile]'s completion, so a test can outlast the service
  /// timeout and prove cancelBatches() fired.
  final Duration? batchDelay;

  final Availability availability;

  /// When true, [checkAvailability] throws, to exercise callers' failure paths.
  final bool throwOnCheckAvailability;

  final List<String> supportedLocaleTags;

  /// Mutable fixture: the tags reported installed AND reserved (this fake keeps
  /// the two axes together). Defaults to everything supported, matching the
  /// always-ready [isModelInstalled].
  final List<String> installedLocaleTags;

  /// The cap [reservationInfo] reports; a fixture, since the real value is
  /// device-dependent.
  int maxReservedLocales;

  final DateTime Function() _clock;

  @override
  String get id => 'fake.streaming';

  @override
  Future<List<String>> supportedLocales() async => supportedLocaleTags;

  @override
  bool get onDeviceOnly => true;

  @override
  Future<Availability> checkAvailability({required String localeId}) async {
    if (throwOnCheckAvailability) throw StateError('fake availability failure');
    return availability;
  }

  @override
  Future<bool> isModelInstalled({required String localeId}) async => true;

  @override
  Stream<ModelInstallProgress> installModel({required String localeId}) async* {
    if (!installedLocaleTags.contains(localeId)) installedLocaleTags.add(localeId);
    yield const ModelInstallProgress(fraction: 1, done: true);
  }

  @override
  Future<List<String>> installedLocales() async => List.of(installedLocaleTags);

  @override
  Future<LocaleModelStatus> localeStatus({required String localeId}) async {
    final installed = installedLocaleTags.contains(localeId);
    return LocaleModelStatus(
      status: !supportedLocaleTags.contains(localeId)
          ? ModelAssetStatus.unsupported
          : (installed ? ModelAssetStatus.installed : ModelAssetStatus.supported),
      reserved: installed,
      resolvedTag: localeId,
    );
  }

  @override
  Future<bool> removeLanguage({required String localeId}) async =>
      installedLocaleTags.remove(localeId);

  @override
  Future<ReservationInfo> reservationInfo() async =>
      ReservationInfo(max: maxReservedLocales, reservedTags: List.of(installedLocaleTags));

  /// Every batch call's (localeId, start, end), newest last, for assertions.
  final List<({String localeId, Duration? start, Duration? end})> batchCalls = [];

  /// Builds per-call text when set (distinguishable spans in merge tests);
  /// falls back to [batchText]/[cannedText].
  String Function(String localeId, Duration? start, Duration? end)? transcriptBuilder;

  @override
  Future<Transcript> transcribeFile(
    File audio, {
    required String localeId,
    Duration? start,
    Duration? end,
  }) async {
    batchCalls.add((localeId: localeId, start: start, end: end));
    if (batchDelay != null) await Future<void>.delayed(batchDelay!);
    if (failBatch) throw const TranscriptionFailed('fake batch failure');
    final text = transcriptBuilder?.call(localeId, start, end) ?? batchText ?? cannedText;
    return _cannedTranscript(text, localeId, id, _clock());
  }

  /// How many times [cancelBatches] was called, for the timeout-cancel test.
  int cancelBatchesCalls = 0;

  @override
  Future<void> cancelBatches() async {
    cancelBatchesCalls++;
  }

  /// The locale the most recent [transcribeLive] was asked for, for assertions.
  String? lastLiveLocaleId;

  @override
  Stream<TranscriptEvent> transcribeLive({required String localeId}) {
    lastLiveLocaleId = localeId;
    // A manual controller, like the real engine and for the same reason: a
    // consumer cancel must complete even while this is parked on [stopSignal]
    // (a mid-take language switch, a discarded take) - an async* generator's
    // cancel would hang there, and the fake must not be kinder than the phone.
    late final StreamController<TranscriptEvent> controller;
    var cancelled = false;
    controller = StreamController<TranscriptEvent>(
      onListen: () async {
        final words = cannedText.split(' ');
        final buffer = StringBuffer();
        for (var i = 0; i < words.length; i++) {
          buffer.write(i == 0 ? words[i] : ' ${words[i]}');
          if (cancelled) return;
          controller.add(TranscriptEvent(text: buffer.toString(), isFinal: false));
        }
        if (failLive) {
          controller.addError(const TranscriptionFailed('fake live failure'));
          await controller.close();
          return;
        }
        await (stopSignal ?? Future<void>.value());
        if (cancelled || controller.isClosed) return;
        if (liveNoFinal) {
          await controller.close();
          return;
        }
        controller.add(
          TranscriptEvent(
            text: cannedText,
            isFinal: true,
            segments: [
              TranscriptSegment(
                text: cannedText,
                start: Duration.zero,
                end: const Duration(seconds: 1),
              ),
            ],
          ),
        );
        await controller.close();
      },
      onCancel: () => cancelled = true,
    );
    return controller.stream;
  }
}

/// Deterministic batch-only engine, the whisper.cpp-shaped double: it is NOT a
/// [StreamingTranscriptionEngine], so it exercises the batch path through the type
/// check, not just the capability flag. Set [failBatch] to fail transcription.
class FakeBatchEngine implements TranscriptionEngine, CancellableBatchEngine {
  FakeBatchEngine({
    this.cannedText = 'batch transcript',
    this.failBatch = false,
    this.throwGeneric = false,
    this.delay,
    this.gate,
    this.supportedLocaleTags = const ['en-US'],
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final String cannedText;

  /// The picker list this fake reports.
  final List<String> supportedLocaleTags;

  /// Throws a [TranscriptionFailed] (the mapped taxonomy). Mutable so a test
  /// can fail a run and then let a retry succeed.
  bool failBatch;

  /// Throws a non-taxonomy error, to prove the service never orphans a recording.
  final bool throwGeneric;

  /// Delays the result, to exercise the batch timeout.
  final Duration? delay;

  /// Holds the batch pass open until this future completes, for tests that need
  /// to interleave an event (a delete, a rename) deterministically rather than
  /// racing a wall-clock [delay].
  final Future<void>? gate;

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

  /// Every batch call's (localeId, start, end), newest last, for assertions.
  final List<({String localeId, Duration? start, Duration? end})> batchCalls = [];

  /// Builds per-call text when set; falls back to [cannedText].
  String Function(String localeId, Duration? start, Duration? end)? transcriptBuilder;

  /// Fails only RANGED calls, the shape of an engine that cannot slice
  /// (pre-26), for fallback tests.
  bool failRanged = false;

  /// How many times [cancelBatches] was called, for the timeout-cancel test.
  int cancelBatchesCalls = 0;

  @override
  Future<void> cancelBatches() async {
    cancelBatchesCalls++;
  }

  @override
  Future<Transcript> transcribeFile(
    File audio, {
    required String localeId,
    Duration? start,
    Duration? end,
  }) async {
    batchCalls.add((localeId: localeId, start: start, end: end));
    if (gate != null) await gate;
    if (delay != null) await Future<void>.delayed(delay!);
    if (throwGeneric) throw StateError('generic engine failure');
    if (failBatch) throw const TranscriptionFailed('fake batch failure');
    if (failRanged && (start != null || end != null)) {
      throw const TranscriptionFailed('ranged transcription unavailable');
    }
    final text = transcriptBuilder?.call(localeId, start, end) ?? cannedText;
    return _cannedTranscript(text, localeId, id, _clock());
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

  /// Fails installs with [ReservationCapReached] instead, for eviction-flow tests.
  bool capReached = false;

  /// Holds an install open after its progress steps, for tests interleaving
  /// other work with an in-flight download.
  Future<void>? installGate;

  /// The cap [reservationInfo] reports; a fixture.
  int maxReservedLocales = 3;

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
  Stream<ModelInstallProgress> installModel({required String localeId}) {
    // Cancel-safe like the real engine (and [FakeStreamingEngine]'s live): a
    // cancel parked on [installGate] must complete; an async* generator's
    // would hang there, and the fake must not be kinder than the phone.
    late final StreamController<ModelInstallProgress> controller;
    var cancelled = false;
    controller = StreamController<ModelInstallProgress>(
      onListen: () async {
        if (capReached) {
          controller.addError(ReservationCapReached(List.of(supportedLocaleTags)));
          await controller.close();
          return;
        }
        if (failInstall) {
          controller.addError(const ModelInstallFailed('fake install failure'));
          await controller.close();
          return;
        }
        for (final fraction in installSteps) {
          if (cancelled) return;
          controller.add(ModelInstallProgress(fraction: fraction, done: false));
        }
        if (installGate != null) await installGate;
        if (cancelled || controller.isClosed) return;
        installed = true;
        controller.add(const ModelInstallProgress(fraction: 1, done: true));
        await controller.close();
      },
      onCancel: () => cancelled = true,
    );
    return controller.stream;
  }

  // This fake models ONE managed model, so the per-language view collapses to
  // the single [installed] flag across every supported tag.

  @override
  Future<List<String>> installedLocales() async =>
      installed ? List.of(supportedLocaleTags) : const [];

  @override
  Future<LocaleModelStatus> localeStatus({required String localeId}) async => LocaleModelStatus(
    status: !supportedLocaleTags.contains(localeId)
        ? ModelAssetStatus.unsupported
        : (installed ? ModelAssetStatus.installed : ModelAssetStatus.supported),
    reserved: installed,
    resolvedTag: localeId,
  );

  @override
  Future<bool> removeLanguage({required String localeId}) async {
    final was = installed;
    installed = false;
    return was;
  }

  @override
  Future<ReservationInfo> reservationInfo() async => ReservationInfo(
    max: maxReservedLocales,
    reservedTags: installed ? List.of(supportedLocaleTags) : const [],
  );

  @override
  Future<Transcript> transcribeFile(
    File audio, {
    required String localeId,
    Duration? start,
    Duration? end,
  }) async => _cannedTranscript(cannedText, localeId, id, _clock());
}
