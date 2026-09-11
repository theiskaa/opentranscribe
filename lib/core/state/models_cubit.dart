import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/services/engine_settings.dart';
import 'package:opentranscribe/core/services/transcription_service.dart';
import 'package:transcriber/transcriber.dart';

/// One model of an engine's choice as the models surface manages it:
/// whether its file is present, whether it is the one runs use, any
/// in-flight download, whether this phone can hold it, and a standing
/// install failure.
@immutable
final class ModelRowState {
  const ModelRowState({
    required this.option,
    required this.installed,
    required this.selected,
    required this.heavy,
    this.accelerated = false,
    this.installFraction,
    this.preparing = false,
    this.queued = false,
    this.cancellable = false,
    this.failure,
  });

  final ModelOption option;
  final bool installed;
  final bool selected;

  /// The model's acceleration file is present beside it.
  final bool accelerated;

  /// The download's bytes are in and the install is unpacking or compiling:
  /// no percent to show, nothing to cancel.
  final bool preparing;

  /// The download is waiting for its turn behind another; nothing has
  /// started yet.
  final bool queued;

  /// The model's peak memory exceeds what this phone can spare.
  final bool heavy;

  /// 0..1 while this model downloads; null otherwise.
  final double? installFraction;

  /// Whether the download in flight is this cubit's to stop: a picker-started
  /// one is, a batch's first-use download is not (a stop would fail the
  /// transcription waiting on it).
  final bool cancellable;

  /// Why the last install failed, until a retry clears it.
  final ModelInstallReason? failure;

  bool get installing => installFraction != null;

  ModelRowState copyWith({
    bool? installed,
    bool? selected,
    bool? heavy,
    bool? accelerated,
    double? installFraction,
    bool? preparing,
    bool? queued,
    bool? cancellable,
    ModelInstallReason? failure,
    bool clearInstall = false,
    bool clearFailure = false,
  }) => ModelRowState(
    option: option,
    installed: installed ?? this.installed,
    selected: selected ?? this.selected,
    heavy: heavy ?? this.heavy,
    accelerated: accelerated ?? this.accelerated,
    installFraction: clearInstall ? null : (installFraction ?? this.installFraction),
    preparing: clearInstall ? false : (preparing ?? this.preparing),
    queued: clearInstall ? false : (queued ?? this.queued),
    cancellable: clearInstall ? false : (cancellable ?? this.cancellable),
    failure: clearFailure ? null : (failure ?? this.failure),
  );
}

/// Whether a model needing [peakBytes] resident is too much for a phone with
/// [physicalBytes]: past three fifths, the share iOS lets a foreground app
/// hold. Unknown memory dims nothing.
bool modelTooHeavy({required int peakBytes, required int? physicalBytes}) =>
    physicalBytes != null && peakBytes * 5 > physicalBytes * 3;

/// What the models surface renders: the active engine's model choice, with
/// its downloads, failures and the acceleration switch. Empty rows under an
/// engine without a choice.
@immutable
final class ModelsState {
  const ModelsState({
    this.engineId = '',
    this.offersModelChoice = false,
    this.offersAcceleration = false,
    this.accelerated = false,
    this.models = const [],
  });

  /// The engine whose answers this state describes, so a surface pairing the
  /// rows with the languages' state can tell a switch-in-flight frame from a
  /// settled one.
  final String engineId;

  /// Whether that engine offers a choice of models, one serving every
  /// language.
  final bool offersModelChoice;

  /// Whether that engine can run its models faster with a second file each,
  /// so the switch shows; [accelerated] is the switch.
  final bool offersAcceleration;
  final bool accelerated;

  /// The engine's models in picker order; empty without a choice.
  final List<ModelRowState> models;

  /// The model runs use, null without a choice.
  ModelRowState? get selectedModel => models.where((row) => row.selected).firstOrNull;

  ModelsState copyWith({
    String? engineId,
    bool? offersModelChoice,
    bool? offersAcceleration,
    bool? accelerated,
    List<ModelRowState>? models,
  }) => ModelsState(
    engineId: engineId ?? this.engineId,
    offersModelChoice: offersModelChoice ?? this.offersModelChoice,
    offersAcceleration: offersAcceleration ?? this.offersAcceleration,
    accelerated: accelerated ?? this.accelerated,
    models: models ?? this.models,
  );
}

/// Drives the models surface over the service: the model rows, their
/// downloads (picker-started or riding a batch pass), the choice, removal,
/// and the acceleration switch.
// ignore_for_file: prefer_initializing_formals
// The fields are private (a cubit owns its collaborators) and the constructor
// must call super(state), so initializing formals do not apply.
class ModelsCubit extends Cubit<ModelsState> {
  ModelsCubit({
    required TranscriptionService service,
    required EngineSettings engineSettings,
    int? physicalMemoryBytes,
  }) : _service = service,
       _engineSettings = engineSettings,
       _physicalMemoryBytes = physicalMemoryBytes,
       super(
         ModelsState(
           engineId: service.engineId,
           offersModelChoice: service.offersModelChoice,
           offersAcceleration: service.offersAcceleration,
           accelerated: service.accelerated,
         ),
       ) {
    // A first-use install riding a transcription, or a removal, must reach
    // this surface without the user re-entering it.
    _modelSub = _service.modelStateChanged.listen((_) => load());
    _passSub = _service.batchProgress.listen(_onPass, onError: (Object _) {});
    unawaited(load());
  }

  final TranscriptionService _service;
  final EngineSettings _engineSettings;
  final int? _physicalMemoryBytes;

  // One in-flight install per model: the single-flight guard AND the marker
  // for which rows keep their fraction across a load() rebuild.
  final Map<String, StreamSubscription<ModelInstallProgress>> _modelInstallSubs = {};
  // The ids whose download the acceleration switch started, so off can end
  // them.
  final Set<String> _accelerationInstalls = {};
  StreamSubscription<void>? _modelSub;
  StreamSubscription<BatchProgress>? _passSub;
  // The pass whose download is painting a model's row, without this cubit
  // having started it; keyed by pass so another pass's events leave it be.
  ({String? entryId, String modelId})? _pass;
  // Models between a refused-or-not removal and their retry's install.
  final Set<String> _reinstalling = {};
  int _loadGeneration = 0;

  /// Rebuilds every model row. In-flight download fractions and standing
  /// failures survive the rebuild; only their own flows clear them.
  Future<void> load() async {
    final generation = ++_loadGeneration;
    final Set<String> installedModels;
    final Set<String> acceleratedModels;
    try {
      installedModels = await _service.installedModels();
      acceleratedModels = await _service.acceleratedModels();
    } catch (e) {
      // The rows stay as they were; the screen reloads on its next entry.
      if (kDebugMode) debugPrint('models load failed: $e');
      return;
    }
    if (isClosed || generation != _loadGeneration) return;
    // Carried state is one engine's story: across a switch the old rows
    // describe the OTHER engine, and its install trackers go with them.
    final sameEngine = state.engineId == _service.engineId;
    if (!sameEngine) {
      for (final sub in _modelInstallSubs.values) {
        unawaited(sub.cancel().catchError((_) {}));
      }
      _modelInstallSubs.clear();
      _pass = null;
    }
    final previousModels = sameEngine
        ? {for (final row in state.models) row.option.id: row}
        : const <String, ModelRowState>{};
    final selectedModel = _service.selectedModelId;
    emit(
      state.copyWith(
        engineId: _service.engineId,
        offersModelChoice: _service.offersModelChoice,
        offersAcceleration: _service.offersAcceleration,
        accelerated: _service.accelerated,
        models: [
          for (final option in _service.modelChoices)
            ModelRowState(
              option: option,
              installed: installedModels.contains(option.id),
              selected: option.id == selectedModel,
              heavy: modelTooHeavy(
                peakBytes: option.peakMemoryBytes,
                physicalBytes: _physicalMemoryBytes,
              ),
              accelerated: acceleratedModels.contains(option.id),
              installFraction:
                  _modelInstallSubs.containsKey(option.id) || option.id == _pass?.modelId
                  ? previousModels[option.id]?.installFraction
                  : null,
              preparing:
                  (_modelInstallSubs.containsKey(option.id) || option.id == _pass?.modelId) &&
                  (previousModels[option.id]?.preparing ?? false),
              queued:
                  _modelInstallSubs.containsKey(option.id) &&
                  (previousModels[option.id]?.queued ?? false),
              cancellable: previousModels[option.id]?.cancellable ?? false,
              failure: _carriedFailure(
                previousModels[option.id]?.failure,
                installed: installedModels.contains(option.id),
                encoderMissing: _service.accelerated && !acceleratedModels.contains(option.id),
              ),
            ),
        ],
      ),
    );
  }

  /// Makes [id] the model runs use, persisted per engine. A failed persist
  /// keeps the in-session choice and rethrows so the surface can say it will
  /// not survive a relaunch.
  Future<void> selectModel(String id) async {
    await _service.selectModel(id);
    await _engineSettings.setModelId(_service.engineId, id);
  }

  /// The selected model's download, for a language surface under one model
  /// for every language. A model too large for this phone is not fetched.
  Future<void> installSelected() async {
    final id = _service.selectedModelId;
    if (id == null) return;
    final row = state.selectedModel;
    if (row != null && row.heavy && !row.installed) return;
    await installModelById(id);
  }

  /// Downloads one model of the engine's choice and selects it once landed. Single-flight per model. A model that
  /// downloaded but would not open is removed first, so the retry fetches a
  /// fresh file; answers false when that removal was refused (a run holds the
  /// model), and the row keeps its failure.
  Future<bool> installModelById(String id) async {
    if (_modelInstallSubs.containsKey(id) || !_reinstalling.add(id)) return true;
    try {
      final row = state.models.where((r) => r.option.id == id).firstOrNull;
      if (row != null && row.installed && row.failure == ModelInstallReason.loadFailed) {
        bool removed;
        try {
          removed = await _service.removeModel(id);
        } catch (_) {
          removed = false;
        }
        if (isClosed) return false;
        if (!removed && (await _service.installedModels()).contains(id)) return false;
      }
      if (isClosed) return false;
      _trackModelInstall(id, () => _service.installModelById(id), selectOnLand: true);
      return true;
    } finally {
      _reinstalling.remove(id);
    }
  }

  /// Turns the engine's acceleration on or off and persists it. On fetches
  /// the extra file of every installed model as a download on its row; off
  /// ends those downloads. The switch takes before the persist, so a refused
  /// write throws after the surfaces moved.
  Future<void> setAccelerated(bool on) async {
    await _service.setAccelerated(on);
    if (isClosed) return;
    emit(state.copyWith(accelerated: on));
    if (on) {
      for (final row in state.models) {
        if (row.installed && !row.accelerated && !row.installing) {
          _accelerationInstalls.add(row.option.id);
          _trackModelInstall(
            row.option.id,
            () => _service.installAcceleration(row.option.id),
            selectOnLand: false,
          );
        }
      }
    } else {
      for (final id in _accelerationInstalls.toList()) {
        await cancelModelInstallById(id);
      }
    }
    unawaited(load());
    await _engineSettings.setAccelerated(_service.engineId, on);
  }

  /// One download on a model's row, from a picker tap or the acceleration
  /// switch; [selectOnLand] is the picker's rule, the download was for
  /// choosing the model.
  void _trackModelInstall(
    String id,
    Stream<ModelInstallProgress> Function() start, {
    required bool selectOnLand,
  }) {
    if (_modelInstallSubs.containsKey(id)) return;
    // The engine and selection this install belongs to: a switch or a pick
    // landing mid-download must not have the landing take the choice.
    final engineId = _service.engineId;
    final selectedAtStart = _service.selectedModelId;
    // Installs of different models run one after the other, so a download
    // started while another holds the engine waits its turn; the engine's
    // first word clears it.
    final waiting = _modelInstallSubs.isNotEmpty;
    _patchModel(
      id,
      (row) =>
          row.copyWith(installFraction: 0, queued: waiting, cancellable: true, clearFailure: true),
    );
    _modelInstallSubs[id] = start().listen(
      (progress) {
        if (progress.done) return;
        _patchModel(
          id,
          (row) => row.copyWith(
            installFraction: progress.fraction,
            queued: false,
            preparing: progress.preparing,
            cancellable: !progress.preparing,
          ),
        );
      },
      onDone: () async {
        _modelInstallSubs.remove(id);
        _accelerationInstalls.remove(id);
        // Installed at once: the file is there, and the reload that says
        // so takes several round trips the row must not spend as a download.
        _patchModel(id, (row) => row.copyWith(clearInstall: true, installed: true));
        // Selecting is what the download was for; a failed persist still
        // leaves the file, so the row reads installed either way.
        if (selectOnLand &&
            _service.engineId == engineId &&
            _service.selectedModelId == selectedAtStart) {
          try {
            await selectModel(id);
          } catch (e) {
            if (kDebugMode) debugPrint('models: model choice not saved: $e');
          }
        }
        unawaited(load());
      },
      // A failed install's stream closes after its error; without this its
      // onDone would mark the model installed and select it.
      cancelOnError: true,
      onError: (Object error) {
        _modelInstallSubs.remove(id);
        _accelerationInstalls.remove(id);
        final failure = _modelFailureFrom(error);
        _patchModel(
          id,
          (row) =>
              row.copyWith(clearInstall: true, failure: failure, clearFailure: failure == null),
        );
        unawaited(load());
      },
    );
  }

  /// Stops a download this cubit started; what arrived stays for a later
  /// resume. A no-op when nothing this cubit started is downloading.
  Future<void> cancelModelInstallById(String id) async {
    final sub = _modelInstallSubs.remove(id);
    _accelerationInstalls.remove(id);
    if (sub == null) return;
    await sub.cancel().catchError((_) {});
    if (isClosed) return;
    _patchModel(id, (row) => row.copyWith(clearInstall: true));
    unawaited(load());
  }

  /// Deletes one model's file. Answers whether one was deleted.
  Future<bool> removeModel(String id) async {
    bool removed;
    try {
      removed = await _service.removeModel(id);
    } catch (_) {
      removed = false;
    }
    if (isClosed) return removed;
    await load();
    return removed;
  }

  /// Folds a raw model install failure into its reason; the raw error is only
  /// ever debug-logged. A cancel is no failure to wear; an error outside the
  /// taxonomy reads as the host refusing, the case
  /// [ModelInstallReason.rejected] covers.
  ModelInstallReason? _modelFailureFrom(Object error) {
    if (kDebugMode) debugPrint('models: $error');
    return switch (error) {
      ModelInstallFailed(reason: ModelInstallReason.cancelled) => null,
      TranscriptionFailed() => null,
      ModelInstallFailed(reason: final reason?) => reason,
      _ => ModelInstallReason.rejected,
    };
  }

  /// A failure a reload keeps. A download failure clears once the file is
  /// there through another path, unless it was the encoder that failed; one
  /// that would not open stands on the present file until a retry replaces it,
  /// and goes with the file.
  static ModelInstallReason? _carriedFailure(
    ModelInstallReason? previous, {
    required bool installed,
    required bool encoderMissing,
  }) => switch (previous) {
    ModelInstallReason.loadFailed => installed ? previous : null,
    _ when installed && !encoderMissing => null,
    _ => previous,
  };

  void _patchModel(String id, ModelRowState Function(ModelRowState) update) {
    emit(
      state.copyWith(
        models: [for (final row in state.models) row.option.id == id ? update(row) : row],
      ),
    );
  }

  /// A batch pass on a model's row: its download painted as it runs, landed
  /// when that pass's run starts (whatever model the run names, since the
  /// choice may have moved meanwhile), and the failure its done carries put
  /// on the model it names. A picker-started download owns its row.
  void _onPass(BatchProgress event) {
    if (isClosed) return;
    final id = event.modelId;
    final pass = _pass;
    final ours = pass != null && pass.entryId == event.entryId;
    switch (event.step) {
      case BatchStep.downloading:
        if (id == null || _modelInstallSubs.containsKey(id)) return;
        final fresh = pass?.modelId != id;
        _pass = (entryId: event.entryId, modelId: id);
        _patchModel(
          id,
          (row) => row.copyWith(
            installFraction: event.fraction,
            preparing: event.preparing,
            clearFailure: fresh,
          ),
        );
      case BatchStep.transcribing:
        if (!ours) return;
        _pass = null;
        _land(pass.modelId, (row) => row.copyWith(clearInstall: true, installed: true));
      case BatchStep.done:
        final failure = event.failure;
        if (ours) {
          _pass = null;
          _land(
            pass.modelId,
            (row) => row.copyWith(clearInstall: true, failure: pass.modelId == id ? failure : null),
          );
        }
        if (failure != null && id != null && !(ours && pass.modelId == id)) {
          _land(id, (row) => row.copyWith(failure: failure));
        }
    }
  }

  void _land(String id, ModelRowState Function(ModelRowState) update) {
    if (!_modelInstallSubs.containsKey(id)) _patchModel(id, update);
  }

  @override
  Future<void> close() async {
    await _modelSub?.cancel();
    await _passSub?.cancel();
    // Over a copy: an install's onDone firing during these awaits removes its
    // own key from the live map.
    for (final sub in List.of(_modelInstallSubs.values)) {
      await sub.cancel().catchError((_) {});
    }
    _modelInstallSubs.clear();
    return super.close();
  }
}
