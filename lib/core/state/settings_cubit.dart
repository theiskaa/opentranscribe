import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/services/audio_storage_settings.dart';
import 'package:opentranscribe/core/services/engine_settings.dart';
import 'package:opentranscribe/core/services/transcription_service.dart';
import 'package:opentranscribe/core/services/transcription_settings.dart';
import 'package:opentranscribe/core/utils/language_tags.dart';
import 'package:transcriber/transcriber.dart';

/// Why a language row failed, as a kind the UI words. [capReached] is not a
/// retry story: the fix is removing one of the languages holding the cap.
/// [removeFailed] marks a removal the platform refused (released nothing);
/// the row itself is usually still ready.
enum LanguageFailureKind { installFailed, capReached, removeFailed }

@immutable
final class LanguageFailure {
  const LanguageFailure({required this.kind, this.assetStatus, this.reservedTags = const []});

  final LanguageFailureKind kind;

  /// The asset's state just before a failed install, when known: a stuck
  /// download and an asset the platform has nothing to serve for deserve
  /// different words than an ordinary network failure.
  final ModelAssetStatus? assetStatus;

  /// The languages holding the cap when [kind] is [capReached], for an
  /// eviction choice.
  final List<String> reservedTags;
}

/// One language as the settings surface manages it: the model's own state,
/// whether this app may use it, whether it is the transcription default, and
/// any in-flight download or standing failure. Per-language on purpose; the
/// single-bool state this replaces is what made "installed" flip whenever the
/// default changed.
@immutable
final class LanguageModelState {
  const LanguageModelState({
    required this.tag,
    required this.status,
    required this.reserved,
    required this.isDefault,
    this.resolvedTag,
    this.installFraction,
    this.failure,
  });

  final String tag;
  final ModelAssetStatus status;
  final bool reserved;
  final bool isDefault;

  /// The canonical tag the engine resolves [tag] to, when the row has been
  /// refined through the fine-grained probe (de-AT answering as de-DE).
  final String? resolvedTag;

  /// 0..1 while this cubit downloads this language; null otherwise.
  final double? installFraction;

  final LanguageFailure? failure;

  bool get isReady => status == ModelAssetStatus.installed && reserved;
  bool get installing => installFraction != null;

  LanguageModelState copyWith({
    ModelAssetStatus? status,
    bool? reserved,
    bool? isDefault,
    String? resolvedTag,
    double? installFraction,
    LanguageFailure? failure,
    bool clearInstall = false,
    bool clearFailure = false,
  }) => LanguageModelState(
    tag: tag,
    status: status ?? this.status,
    reserved: reserved ?? this.reserved,
    isDefault: isDefault ?? this.isDefault,
    resolvedTag: resolvedTag ?? this.resolvedTag,
    installFraction: clearInstall ? null : (installFraction ?? this.installFraction),
    failure: clearFailure ? null : (failure ?? this.failure),
  );
}

/// One model of an engine's choice as the settings surface manages it:
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

/// What the settings surfaces render about the transcription and storage
/// backbone: the default language, one row per language, the engine's
/// model choice when it has one, and the backup preference.
@immutable
final class SettingsState {
  const SettingsState({
    this.localeId = '',
    this.engineId = '',
    this.managesModels = false,
    this.offersModelChoice = false,
    this.offersAcceleration = false,
    this.accelerated = false,
    this.supportedLocales = const [],
    this.languages = const [],
    this.models = const [],
    this.reservationMax = 0,
    this.backupExcluded = true,
    this.keepAudio = true,
    this.deviceLanguageUnsupported = false,
    this.loadFailed = false,
  });

  final String localeId;

  /// The engine whose answers this state describes, so a surface pairing these
  /// rows with the picker's active engine can tell a switch-in-flight frame
  /// from a settled one.
  final String engineId;

  /// Whether that engine manages downloadable models. Wording keys off this
  /// (an unready language's story), never off [reservationMax], which only
  /// gates affordances.
  final bool managesModels;

  /// Whether that engine offers a choice of models, one serving every
  /// language: the model card shows, and the language surfaces keep only
  /// the default as yours.
  final bool offersModelChoice;

  /// The engine's models in picker order; empty without a choice.
  final List<ModelRowState> models;

  /// Whether that engine can run its models faster with a second file each,
  /// so the switch shows; [accelerated] is the switch.
  final bool offersAcceleration;
  final bool accelerated;

  /// The model runs use, null without a choice.
  ModelRowState? get selectedModel => models.where((row) => row.selected).firstOrNull;

  /// True when the phone's language has no on-device model in any variant and
  /// the current default equals the derived fallback, so a surface can say why
  /// the default is not the phone's language.
  final bool deviceLanguageUnsupported;

  /// The last load never reached the engine, so [languages] is whatever the
  /// load before it left (nothing, on a first load). A surface waiting on a
  /// row stops waiting; the next successful load clears this.
  final bool loadFailed;

  /// The engine's raw tag list, kept beside the rows for callers that need
  /// plain membership (the rows add installed extras and the kept default).
  final List<String> supportedLocales;

  /// One row per language: the engine's supported list, plus any installed
  /// extras, plus the default when it appears in neither (an unsupported
  /// choice kept honestly).
  final List<LanguageModelState> languages;

  /// The platform's language cap; 0 means no cap concept. Gates install and
  /// remove affordances and the slot line only; see [managesModels] for
  /// wording.
  final int reservationMax;

  final bool backupExcluded;

  /// Whether recordings survive a successful transcription (see
  /// AudioStorageSettings.keepAudio).
  final bool keepAudio;

  LanguageModelState? get defaultLanguage {
    for (final row in languages) {
      if (row.isDefault) return row;
    }
    return null;
  }

  /// The languages a picker may offer: the default (kept honestly even when
  /// not ready), every ready row, and, where no reservation concept exists
  /// (pre-26), every supported row since none needs an install there. The one
  /// rule for every language chooser, so they can never disagree.
  List<String> selectableLanguageTags() {
    final tags = <String>[];
    void add(String tag) {
      if (tag.isNotEmpty && !tags.contains(tag)) tags.add(tag);
    }

    add(localeId);
    for (final row in languages) {
      if (row.isReady || (reservationMax == 0 && row.status != ModelAssetStatus.unsupported)) {
        add(row.tag);
      }
    }
    return tags;
  }

  SettingsState copyWith({
    String? localeId,
    String? engineId,
    bool? managesModels,
    bool? offersModelChoice,
    bool? offersAcceleration,
    bool? accelerated,
    List<ModelRowState>? models,
    List<String>? supportedLocales,
    List<LanguageModelState>? languages,
    int? reservationMax,
    bool? backupExcluded,
    bool? keepAudio,
    bool? deviceLanguageUnsupported,
    bool? loadFailed,
  }) => SettingsState(
    localeId: localeId ?? this.localeId,
    engineId: engineId ?? this.engineId,
    managesModels: managesModels ?? this.managesModels,
    offersModelChoice: offersModelChoice ?? this.offersModelChoice,
    offersAcceleration: offersAcceleration ?? this.offersAcceleration,
    accelerated: accelerated ?? this.accelerated,
    models: models ?? this.models,
    supportedLocales: supportedLocales ?? this.supportedLocales,
    languages: languages ?? this.languages,
    reservationMax: reservationMax ?? this.reservationMax,
    backupExcluded: backupExcluded ?? this.backupExcluded,
    keepAudio: keepAudio ?? this.keepAudio,
    deviceLanguageUnsupported: deviceLanguageUnsupported ?? this.deviceLanguageUnsupported,
    loadFailed: loadFailed ?? this.loadFailed,
  );
}

/// Drives the settings surfaces over the idle backbone: the default language,
/// per-language model state and installs, and the backup preference. Theme
/// mode and app language live elsewhere (ThemeCubit, AppLanguage).
// ignore_for_file: prefer_initializing_formals
// The fields are private (a cubit owns its collaborators) and the constructor
// must call super(state), so initializing formals do not apply.
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit({
    required TranscriptionService service,
    required TranscriptionSettings transcription,
    required AudioStorageSettings audioStorage,
    required EngineSettings engineSettings,
    int? physicalMemoryBytes,
  }) : _service = service,
       _transcription = transcription,
       _audioStorage = audioStorage,
       _engineSettings = engineSettings,
       _physicalMemoryBytes = physicalMemoryBytes,
       // Seeded from the synchronous holders rather than defaulted: [load] needs
       // several channel round trips to answer, and a Cache screen that renders
       // "keep audio on" for a second before flipping itself off is telling the
       // user their setting is something it is not.
       super(
         SettingsState(
           localeId: transcription.localeId,
           engineId: service.engineId,
           managesModels: service.managesModels,
           offersModelChoice: service.offersModelChoice,
           offersAcceleration: service.offersAcceleration,
           accelerated: service.accelerated,
           backupExcluded: audioStorage.backupExcluded,
           keepAudio: audioStorage.keepAudio,
         ),
       ) {
    // A first-use install piggybacking on a transcription, or a removal, must
    // reach this surface without the user re-entering settings.
    _modelSub = _service.modelStateChanged.listen((_) => load());
    _passSub = _service.batchProgress.listen(_onPass, onError: (Object _) {});
    unawaited(load());
  }

  final TranscriptionService _service;
  final TranscriptionSettings _transcription;
  final AudioStorageSettings _audioStorage;
  final EngineSettings _engineSettings;
  final int? _physicalMemoryBytes;

  // One in-flight install per tag: the single-flight guard AND the marker for
  // which rows keep their fraction across a load() rebuild.
  final Map<String, StreamSubscription<ModelInstallProgress>> _installSubs = {};
  // The same, per model of the engine's choice.
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

  /// Rebuilds every language row and, under an engine with a choice, every
  /// model row. Cheap by design: list calls plus ONE
  /// fine-grained probe for the default row (whose readiness the pre-merge
  /// screens render); other rows derive from list membership, and a surface
  /// that shows one can refine it via [refreshLanguage]. In-flight download
  /// fractions and standing failures survive the rebuild; only their own
  /// flows clear them.
  Future<void> load() async {
    // Overlapping loads (a rapid locale double-pick) must not let the older
    // one land last and revert the newer state.
    final generation = ++_loadGeneration;
    final localeId = _transcription.localeId;
    final List<String> supported;
    final List<String> installed;
    final ReservationInfo reservations;
    final LocaleModelStatus? defaultStatus;
    final Set<String> installedModels;
    final Set<String> acceleratedModels;
    try {
      supported = await _service.supportedLocales();
      installed = await _service.installedLocales();
      reservations = await _service.reservationInfo();
      defaultStatus = localeId.isEmpty ? null : await _service.localeStatus(localeId);
      installedModels = await _service.installedModels();
      acceleratedModels = await _service.acceleratedModels();
    } catch (e) {
      // A refusing channel is not an empty language list: the rows stay as
      // they were, and load() never throws into an unawaited caller.
      if (kDebugMode) debugPrint('settings load failed: $e');
      if (!isClosed && generation == _loadGeneration) emit(state.copyWith(loadFailed: true));
      return;
    }
    if (isClosed || generation != _loadGeneration) return;

    final tags = <String>[...supported];
    for (final tag in installed) {
      if (!tags.contains(tag)) tags.add(tag);
    }
    // A stored choice whose language lost support, or a startup whose engine
    // answered no languages; the derived default otherwise resolves before it
    // can get here.
    if (localeId.isNotEmpty && !tags.contains(localeId)) tags.add(localeId);
    tags.sort(languageTagCompare);

    // Carried state is one engine's story: across a switch the old rows'
    // statuses, failures, and download fractions describe the OTHER engine,
    // so the first load after one starts from scratch. The old engine's
    // install trackers go with them.
    final sameEngine = state.engineId == _service.engineId;
    if (!sameEngine) {
      for (final sub in [..._installSubs.values, ..._modelInstallSubs.values]) {
        // Best effort, like the service's own teardown: a rejecting cancel
        // must not land in the zone.
        unawaited(sub.cancel().catchError((_) {}));
      }
      _installSubs.clear();
      _modelInstallSubs.clear();
      _pass = null;
    }
    final previousModels = sameEngine
        ? {for (final row in state.models) row.option.id: row}
        : const <String, ModelRowState>{};
    final selectedModel = _service.selectedModelId;
    final modelRows = [
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
          installFraction: _modelInstallSubs.containsKey(option.id) || option.id == _pass?.modelId
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
    ];
    final previous = sameEngine
        ? {for (final row in state.languages) row.tag: row}
        : const <String, LanguageModelState>{};
    // Where readiness is a per-language probe (the dictation engine), the
    // coarse installed list claims everything and would flash every row ready
    // until the refine wave lands; carrying the last refined status (or
    // starting at supported) keeps rows honest and their sections stable, and
    // no tap can promote a language the engine has not yet vouched for.
    final probes = _service.probesLanguageReadiness;
    final rows = <LanguageModelState>[];
    for (final tag in tags) {
      final refined = tag == localeId ? defaultStatus : null;
      final status =
          refined?.status ??
          (probes
              ? (previous[tag]?.status ?? ModelAssetStatus.supported)
              : (installed.contains(tag)
                    ? ModelAssetStatus.installed
                    : ModelAssetStatus.supported));
      // max 0 means no reservation concept (pre-26, unmanaged engines):
      // usable is the honest default there.
      final reserved =
          refined?.reserved ?? (reservations.max == 0 || reservations.reservedTags.contains(tag));
      final ready = status == ModelAssetStatus.installed && reserved;
      rows.add(
        LanguageModelState(
          tag: tag,
          status: status,
          reserved: reserved,
          isDefault: tag == localeId,
          resolvedTag: refined?.resolvedTag,
          installFraction: _installSubs.containsKey(tag) ? previous[tag]?.installFraction : null,
          // A standing failure survives rebuilds UNLESS the language became
          // ready through another path (a first-use install during
          // transcription): a ready row wearing "download failed" is a lie.
          // A removal failure is the exception: it lives on a ready row by
          // nature, so readiness cannot clear it.
          failure: ready && previous[tag]?.failure?.kind != LanguageFailureKind.removeFailed
              ? null
              : previous[tag]?.failure,
        ),
      );
    }
    emit(
      state.copyWith(
        localeId: localeId,
        engineId: _service.engineId,
        managesModels: _service.managesModels,
        offersModelChoice: _service.offersModelChoice,
        offersAcceleration: _service.offersAcceleration,
        accelerated: _service.accelerated,
        supportedLocales: supported,
        languages: _mirrorSelectedModel(rows, modelRows),
        models: modelRows,
        reservationMax: reservations.max,
        backupExcluded: _audioStorage.backupExcluded,
        keepAudio: _audioStorage.keepAudio,
        deviceLanguageUnsupported:
            _transcription.deviceLanguageUnsupported && localeId == _transcription.deviceLocaleId,
        loadFailed: false,
      ),
    );
    // Where readiness is knowable per language without side effects (the
    // dictation engine's system models), the coarse membership derivation
    // above overstates it, so every load ends by refining every row. Riding
    // the load, not a screen, so a switch's last load always lands honest and
    // a superseded load's refinements die on the generation guard.
    if (probes) {
      for (final tag in tags) {
        unawaited(refreshLanguage(tag));
      }
    }
  }

  /// Refines one row through the engine's fine-grained probe: the list load
  /// derives rows from membership, and a row the user is looking at can
  /// afford the exact answer (stuck downloads, near-variant resolution).
  Future<void> refreshLanguage(String tag) async {
    // Same staleness rule as load(): a slow probe must not land after a
    // newer load (a remove's rebuild) and stamp the old state back on.
    final generation = _loadGeneration;
    final status = await _service.localeStatus(tag);
    if (isClosed || generation != _loadGeneration) return;
    _patchRow(
      tag,
      (row) => row.copyWith(
        status: status.status,
        reserved: status.reserved,
        resolvedTag: status.resolvedTag,
      ),
    );
  }

  /// Persists the transcription default. Other rows' state is untouched: the
  /// default is a flag on one row, not a lens the whole list is recomputed
  /// through.
  Future<void> setLocale(String tag) async {
    await _transcription.setLocaleId(tag);
    await load();
  }

  /// Downloads the model for [tag] (the current default when omitted).
  /// Single-flight PER LANGUAGE: a second tap on an installing row is a
  /// no-op, while another language may install concurrently.
  void install([String? tag]) {
    final target = tag ?? state.localeId;
    if (target.isEmpty || _installSubs.containsKey(target)) return;
    // One model serves every language: the download is the selected model's,
    // tracked on its row and mirrored onto the default's.
    final selected = _service.selectedModelId;
    if (_service.offersModelChoice && selected != null) {
      final row = state.selectedModel;
      if (row != null && row.heavy && !row.installed) return;
      unawaited(installModelById(selected));
      return;
    }
    _patchRow(target, (row) => row.copyWith(installFraction: 0, clearFailure: true));
    _installSubs[target] = _service
        .installModel(localeId: target)
        .listen(
          (progress) {
            if (progress.done) return;
            _patchRow(target, (row) => row.copyWith(installFraction: progress.fraction));
          },
          onDone: () {
            _installSubs.remove(target);
            _patchRow(target, (row) => row.copyWith(clearInstall: true));
            unawaited(load());
          },
          cancelOnError: true,
          onError: (Object error) {
            _installSubs.remove(target);
            _patchRow(
              target,
              (row) => row.copyWith(clearInstall: true, failure: _failureFrom(error)),
            );
            // The failed attempt may still have changed asset state (a reservation
            // taken, a download left pending); re-read rather than trust the
            // snapshot. The failure survives the reload until a retry clears it.
            unawaited(load());
          },
        );
  }

  /// Makes [id] the model runs use, persisted per engine. A failed persist
  /// keeps the in-session choice and rethrows so the surface can say it will
  /// not survive a relaunch.
  Future<void> selectModel(String id) async {
    await _service.selectModel(id);
    await _engineSettings.setModelId(_service.engineId, id);
  }

  /// Like [install], but for one model of the engine's choice: downloads it
  /// and selects it once landed. Single-flight per model. A model that
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
            if (kDebugMode) debugPrint('settings: model choice not saved: $e');
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
    if (kDebugMode) debugPrint('settings: $error');
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
    final rows = [for (final row in state.models) row.option.id == id ? update(row) : row];
    emit(state.copyWith(models: rows, languages: _mirrorSelectedModel(state.languages, rows)));
  }

  /// Under one model for every language the default row's download is the
  /// selected model's, so its fraction is that row's.
  List<LanguageModelState> _mirrorSelectedModel(
    List<LanguageModelState> languages,
    List<ModelRowState> models,
  ) {
    if (!_service.offersModelChoice) return languages;
    final fraction = models.where((row) => row.selected).firstOrNull?.installFraction;
    return [
      for (final row in languages)
        row.isDefault
            ? row.copyWith(installFraction: fraction, clearInstall: fraction == null)
            : row,
    ];
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

  /// Removes a language: releases this app's claim on its model. Removing the
  /// default falls the default back to the device locale, exactly like a
  /// fresh install; never silently to another random language, and never at
  /// all when nothing was actually released (a no-op removal must not carry a
  /// side effect the user did not ask for).
  Future<bool> remove(String tag) async {
    // Single-flight per tag: the disc stays tappable while a removal's round
    // trip is in flight, and the duplicate would find nothing left to release
    // and stamp "couldn't remove" over a removal that just succeeded.
    if (!_removals.add(tag)) return false;
    try {
      return await _remove(tag);
    } finally {
      _removals.remove(tag);
    }
  }

  final Set<String> _removals = {};

  Future<bool> _remove(String tag) async {
    // The engine this removal belongs to: a switch landing mid-flight must
    // not let its verdict stamp the NEXT engine's row.
    final engineId = _service.engineId;
    // A fresh attempt clears the last one's verdict either way.
    _patchRow(tag, (row) => row.copyWith(clearFailure: true));
    // A thrown channel call is a refused removal, not an escape: the stamp
    // below is the row's whole story once the old one was cleared.
    bool released;
    try {
      released = await _service.removeLanguage(tag);
    } catch (_) {
      released = false;
    }
    if (isClosed) return released;
    // Against the settings' truth, not cubit state: a just-picked default is
    // in storage before the load that would update state.localeId lands, and
    // this fallback must not overwrite it.
    if (released && tag == _transcription.localeId) {
      await _transcription.setLocaleId(_transcription.deviceLocaleId);
    }
    await load();
    if (isClosed) return released;
    if (!released && _service.engineId == engineId) {
      // Nothing was released: say so on the row instead of pretending the
      // swipe did something. The failure stands until a retry clears it.
      _patchRow(
        tag,
        (row) =>
            row.copyWith(failure: const LanguageFailure(kind: LanguageFailureKind.removeFailed)),
      );
    }
    return released;
  }

  /// The cap-recovery move as one gesture: frees a slot by removing
  /// [evictTag], then retries the blocked [installTag]. A refused removal
  /// skips the retry; the evicted row already wears its own failure.
  Future<void> evictAndInstall(String evictTag, String installTag) async {
    final engineId = _service.engineId;
    final released = await remove(evictTag);
    if (isClosed || !released) return;
    // An engine switched under the gesture would receive the install instead
    // of the one whose cap the eviction freed; drop the retry, the row's own
    // affordances remain.
    if (_service.engineId != engineId) return;
    install(installTag);
  }

  Future<void> setBackupExcluded(bool excluded) async {
    await _audioStorage.setExcluded(excluded);
    if (isClosed) return;
    emit(state.copyWith(backupExcluded: _audioStorage.backupExcluded));
  }

  /// Optimistic: the toggle reflects the tap immediately (a slow encrypted
  /// write would otherwise spring the knob back and forward again), then the
  /// settle emit re-reads storage. A REFUSED persist keeps the tapped value
  /// in the prefs cache until relaunch (see LocalService.write), so the
  /// session stays self-consistent with what the service reads; the toggle
  /// reverts only at next launch.
  Future<void> setKeepAudio(bool keep) async {
    emit(state.copyWith(keepAudio: keep));
    try {
      await _audioStorage.setKeepAudio(keep);
    } catch (e) {
      if (kDebugMode) debugPrint('settings: keep-audio persist failed: $e');
    }
    if (isClosed) return;
    emit(state.copyWith(keepAudio: _audioStorage.keepAudio));
  }

  void _patchRow(String tag, LanguageModelState Function(LanguageModelState) update) {
    final rows = [for (final row in state.languages) row.tag == tag ? update(row) : row];
    emit(state.copyWith(languages: rows));
  }

  /// Folds a raw install failure into the kind the UI words; the raw error is
  /// only ever debug-logged.
  LanguageFailure _failureFrom(Object error) {
    if (kDebugMode) debugPrint('settings: $error');
    return switch (error) {
      ReservationCapReached(reservedTags: final tags) => LanguageFailure(
        kind: LanguageFailureKind.capReached,
        reservedTags: tags,
      ),
      ModelInstallFailed(assetStatus: final status) => LanguageFailure(
        kind: LanguageFailureKind.installFailed,
        assetStatus: status,
      ),
      _ => const LanguageFailure(kind: LanguageFailureKind.installFailed),
    };
  }

  @override
  Future<void> close() async {
    await _modelSub?.cancel();
    await _passSub?.cancel();
    // Over a copy: an install's onDone firing during these awaits removes its
    // own key from the live map, which would invalidate this iteration. A
    // rejecting cancel must not abort the close and leak the cubit open.
    for (final sub in [...List.of(_installSubs.values), ...List.of(_modelInstallSubs.values)]) {
      await sub.cancel().catchError((_) {});
    }
    _installSubs.clear();
    _modelInstallSubs.clear();
    return super.close();
  }
}
