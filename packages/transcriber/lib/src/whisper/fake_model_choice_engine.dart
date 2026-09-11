import 'dart:async';
import 'dart:io';

import 'package:transcriber/src/transcribe/transcript.dart';
import 'package:transcriber/src/transcribe/transcription_engine.dart';
import 'package:transcriber/src/transcribe/transcription_exception.dart';

/// Deterministic engine shaped like WhisperEngine: batch-only, one model of
/// several serves every language, so a caller's model-choice surfaces can be
/// pinned without a catalog or a file system. Every knob is mutable, so a
/// test flips it between calls. Simpler than the real engine on purpose:
/// [batchBudget] has no floor, installs of different ids run concurrently,
/// and [localeStatus] echoes the tag it was asked for.
class FakeModelChoiceEngine
    implements
        TranscriptionEngine,
        ManagedModelEngine,
        CancellableBatchEngine,
        ModelChoiceEngine,
        PacedBatchEngine,
        ReleasableEngine,
        ProgressBatchEngine,
        AcceleratedModelEngine {
  FakeModelChoiceEngine({
    this.models = const [
      ModelOption(
        id: 'small',
        displayName: 'Small',
        bytes: 100,
        quality: ModelQuality.better,
        peakMemoryBytes: 1000,
        accelerationBytes: 40,
      ),
      ModelOption(
        id: 'large',
        displayName: 'Large',
        bytes: 500,
        quality: ModelQuality.top,
        peakMemoryBytes: 5000,
        accelerationBytes: 200,
      ),
    ],
    String? selected,
    Set<String> installed = const {},
    this.canAccelerate = false,
    bool accelerated = false,
    Set<String> acceleratedModelIds = const {},
    this.installSteps = const [0.5],
    this.failInstall,
    this.installGate,
    this.supportedLocaleTags = const ['en-US', 'de-DE'],
    this.cannedText = 'batch transcript',
    this.budgetFactor = 3,
    this.batchDelay,
    this.serialRuns = false,
    this.progressSteps = const [],
    DateTime Function()? clock,
  }) : installed = Set.of(installed),
       acceleratedIds = Set.of(acceleratedModelIds),
       _accelerated = canAccelerate && accelerated,
       _selected = selected ?? models.first.id,
       _clock = clock ?? DateTime.now;

  @override
  final List<ModelOption> models;

  /// The ids whose files are present; an install adds, a removal takes away.
  final Set<String> installed;

  /// The ids whose extra file is present.
  final Set<String> acceleratedIds;

  @override
  final bool canAccelerate;
  bool _accelerated;

  /// Every acceleration install asked for, in order.
  final List<String> accelerationInstalls = [];

  /// The fractions an install replays before it lands.
  List<double> installSteps;

  /// Fails every install with this reason; null lets them land.
  ModelInstallReason? failInstall;

  /// Holds an install open after its steps, for tests interleaving other work.
  Future<void>? installGate;

  /// Holds an install open while it reads as preparing, after its bytes.
  Future<void>? prepareGate;

  /// Holds an install before its first word, the engine's queue.
  Future<void>? startGate;
  final List<String> supportedLocaleTags;
  final String cannedText;

  /// What [batchBudget] multiplies the audio length by.
  int budgetFactor;

  /// Holds a batch, for timeout tests.
  Duration? batchDelay;

  /// Runs one batch at a time, the way whisper.cpp's engine does.
  final bool serialRuns;
  Future<void> _runs = Future<void>.value();

  /// The fractions a reporting batch replays before its delay.
  List<double> progressSteps;

  /// A fraction reported after the delay, for a listener that gave up.
  double? lateProgress;
  final DateTime Function() _clock;

  String _selected;

  /// Every install and removal asked for, in order.
  final List<String> installs = [];
  final List<String> removals = [];

  /// How many times [cancelBatches] was called, for the timeout-cancel test.
  int cancelBatchesCalls = 0;

  /// Refuses every removal, the engine's answer while a run holds the model.
  bool refuseRemove = false;

  /// How many times a caller released this engine's memory.
  int releases = 0;

  @override
  String get id => 'fake.choice';

  @override
  bool get onDeviceOnly => true;

  @override
  Future<Availability> checkAvailability({required String localeId}) async =>
      supportedLocaleTags.contains(localeId)
      ? const Availability.available()
      : const Availability(AvailabilityStatus.onDeviceUnavailable);

  @override
  Future<List<String>> supportedLocales() async => supportedLocaleTags;

  @override
  Future<Transcript> transcribeFile(
    File audio, {
    required String localeId,
    Duration? start,
    Duration? end,
  }) => transcribeFileWithProgress(
    audio,
    localeId: localeId,
    start: start,
    end: end,
    onProgress: (_) {},
  );

  @override
  Future<Transcript> transcribeFileWithProgress(
    File audio, {
    required String localeId,
    required void Function(double fraction) onProgress,
    Duration? start,
    Duration? end,
  }) {
    if (!serialRuns) return _run(localeId, onProgress);
    final run = _runs.then((_) => _run(localeId, onProgress));
    _runs = run.then((_) {}, onError: (Object _) {});
    return run;
  }

  Future<Transcript> _run(String localeId, void Function(double fraction) onProgress) async {
    for (final step in progressSteps) {
      onProgress(step);
    }
    final delay = batchDelay;
    if (delay != null) await Future<void>.delayed(delay);
    if (lateProgress case final late?) onProgress(late);
    return Transcript(
      fullText: cannedText,
      segments: [
        TranscriptSegment(text: cannedText, start: Duration.zero, end: const Duration(seconds: 1)),
      ],
      localeId: localeId,
      engineId: id,
      createdAt: _clock(),
    );
  }

  @override
  Future<void> cancelBatches() async {
    cancelBatchesCalls++;
  }

  @override
  Future<void> release() async {
    releases++;
  }

  @override
  Duration batchBudget(Duration audio) => audio * budgetFactor;

  @override
  String get selectedModelId => _selected;

  @override
  Future<void> selectModel(String id) async {
    if (!models.any((m) => m.id == id)) throw ArgumentError.value(id, 'id');
    _selected = id;
  }

  @override
  Future<Set<String>> installedModels() async => Set.of(installed);

  @override
  Stream<ModelInstallProgress> installModelById(String id) {
    if (!models.any((m) => m.id == id)) throw ArgumentError.value(id, 'id');
    installs.add(id);
    return _installing(id, withModel: true, withEncoder: _accelerated);
  }

  Stream<ModelInstallProgress> _installing(
    String id, {
    required bool withModel,
    required bool withEncoder,
  }) {
    late final StreamController<ModelInstallProgress> controller;
    var cancelled = false;
    controller = StreamController<ModelInstallProgress>(
      onListen: () async {
        final needModel = withModel && !installed.contains(id);
        final needEncoder = withEncoder && !acceleratedIds.contains(id);
        if (!needModel && !needEncoder) {
          controller.add(const ModelInstallProgress(fraction: 1, done: true));
          await controller.close();
          return;
        }
        final starting = startGate;
        if (starting != null) await starting;
        if (cancelled) return;
        controller.add(const ModelInstallProgress(fraction: 0, done: false));
        for (final fraction in installSteps) {
          if (cancelled) return;
          controller.add(ModelInstallProgress(fraction: fraction, done: false));
        }
        final held = installGate;
        if (held != null) await held;
        if (cancelled) return;
        final reason = failInstall;
        if (reason != null) {
          controller.addError(ModelInstallFailed('fake install failure', null, reason));
        } else {
          if (needModel) installed.add(id);
          if (needEncoder) {
            controller.add(const ModelInstallProgress(fraction: 1, done: false, preparing: true));
            final preparing = prepareGate;
            if (preparing != null) await preparing;
            if (cancelled) return;
            acceleratedIds.add(id);
          }
          controller.add(const ModelInstallProgress(fraction: 1, done: true));
        }
        await controller.close();
      },
      onCancel: () => cancelled = true,
    );
    return controller.stream;
  }

  @override
  Future<bool> removeModel(String id) async {
    if (!models.any((m) => m.id == id)) throw ArgumentError.value(id, 'id');
    removals.add(id);
    if (refuseRemove) return false;
    acceleratedIds.remove(id);
    return installed.remove(id);
  }

  @override
  bool get accelerated => _accelerated;

  @override
  Future<void> setAccelerated(bool on) async {
    if (!canAccelerate) return;
    _accelerated = on;
    if (!on) acceleratedIds.clear();
  }

  @override
  Future<Set<String>> acceleratedModels() async => Set.of(acceleratedIds);

  @override
  Stream<ModelInstallProgress> installAcceleration(String id) {
    if (!models.any((m) => m.id == id)) throw ArgumentError.value(id, 'id');
    accelerationInstalls.add(id);
    return _installing(id, withModel: false, withEncoder: canAccelerate);
  }

  @override
  Future<bool> isModelInstalled({required String localeId}) async => installed.contains(_selected);

  @override
  Stream<ModelInstallProgress> installModel({required String localeId}) =>
      installModelById(_selected);

  @override
  Future<List<String>> installedLocales() async =>
      installed.contains(_selected) ? supportedLocaleTags : const [];

  @override
  Future<LocaleModelStatus> localeStatus({required String localeId}) async => LocaleModelStatus(
    status: !supportedLocaleTags.contains(localeId)
        ? ModelAssetStatus.unsupported
        : installed.contains(_selected)
        ? ModelAssetStatus.installed
        : ModelAssetStatus.supported,
    reserved: supportedLocaleTags.contains(localeId),
    resolvedTag: localeId,
  );

  @override
  Future<bool> removeLanguage({required String localeId}) async => false;

  @override
  Future<ReservationInfo> reservationInfo() async =>
      const ReservationInfo(max: 0, reservedTags: []);
}
