import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/services/audio_storage_settings.dart';
import 'package:opentranscribe/core/services/transcription_service.dart';
import 'package:opentranscribe/core/services/transcription_settings.dart';
import 'package:opentranscribe/core/transcribe/transcription_engine.dart';
import 'package:opentranscribe/core/transcribe/transcription_exception.dart';

/// Why a language row failed, as a kind the UI words. [capReached] is not a
/// retry story: the fix is removing one of the languages holding the cap.
enum LanguageFailureKind { installFailed, capReached }

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

/// What the settings surfaces render about the transcription and storage
/// backbone: the default language, one row per language, and the backup
/// preference.
@immutable
final class SettingsState {
  const SettingsState({
    this.localeId = '',
    this.supportedLocales = const [],
    this.languages = const [],
    this.reservationMax = 0,
    this.backupExcluded = true,
  });

  final String localeId;

  /// The engine's raw tag list, kept beside the rows for callers that need
  /// plain membership (the rows add installed extras and the kept default).
  final List<String> supportedLocales;

  /// One row per language: the engine's supported list, plus any installed
  /// extras, plus the default when it appears in neither (an unsupported
  /// choice kept honestly).
  final List<LanguageModelState> languages;

  /// The platform's language cap; 0 means no cap concept, render none.
  final int reservationMax;

  final bool backupExcluded;

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
    List<String>? supportedLocales,
    List<LanguageModelState>? languages,
    int? reservationMax,
    bool? backupExcluded,
  }) => SettingsState(
    localeId: localeId ?? this.localeId,
    supportedLocales: supportedLocales ?? this.supportedLocales,
    languages: languages ?? this.languages,
    reservationMax: reservationMax ?? this.reservationMax,
    backupExcluded: backupExcluded ?? this.backupExcluded,
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
  }) : _service = service,
       _transcription = transcription,
       _audioStorage = audioStorage,
       super(const SettingsState()) {
    // A first-use install piggybacking on a transcription, or a removal, must
    // reach this surface without the user re-entering settings.
    _modelSub = _service.modelStateChanged.listen((_) => load());
    unawaited(load());
  }

  final TranscriptionService _service;
  final TranscriptionSettings _transcription;
  final AudioStorageSettings _audioStorage;

  // One in-flight install per tag: the single-flight guard AND the marker for
  // which rows keep their fraction across a load() rebuild.
  final Map<String, StreamSubscription<ModelInstallProgress>> _installSubs = {};
  StreamSubscription<void>? _modelSub;
  int _loadGeneration = 0;

  /// Rebuilds every language row. Cheap by design: three list calls plus ONE
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
    final supported = await _service.supportedLocales();
    final installed = await _service.installedLocales();
    final reservations = await _service.reservationInfo();
    final defaultStatus = localeId.isEmpty ? null : await _service.localeStatus(localeId);
    if (isClosed || generation != _loadGeneration) return;

    final tags = <String>[...supported];
    for (final tag in installed) {
      if (!tags.contains(tag)) tags.add(tag);
    }
    if (localeId.isNotEmpty && !tags.contains(localeId)) tags.add(localeId);

    final previous = {for (final row in state.languages) row.tag: row};
    final rows = <LanguageModelState>[];
    for (final tag in tags) {
      final refined = tag == localeId ? defaultStatus : null;
      final status =
          refined?.status ??
          (installed.contains(tag) ? ModelAssetStatus.installed : ModelAssetStatus.supported);
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
          failure: ready ? null : previous[tag]?.failure,
        ),
      );
    }
    emit(
      state.copyWith(
        localeId: localeId,
        supportedLocales: supported,
        languages: rows,
        reservationMax: reservations.max,
        backupExcluded: _audioStorage.backupExcluded,
      ),
    );
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

  /// Removes a language: releases this app's claim on its model. Removing the
  /// default falls the default back to the device locale, exactly like a
  /// fresh install; never silently to another random language, and never at
  /// all when nothing was actually released (a no-op removal must not carry a
  /// side effect the user did not ask for).
  Future<void> remove(String tag) async {
    final released = await _service.removeLanguage(tag);
    if (isClosed) return;
    if (released && tag == state.localeId) {
      await _transcription.setLocaleId(_transcription.deviceLocaleId);
    }
    await load();
  }

  Future<void> setBackupExcluded(bool excluded) async {
    await _audioStorage.setExcluded(excluded);
    if (isClosed) return;
    emit(state.copyWith(backupExcluded: _audioStorage.backupExcluded));
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
    // Over a copy: an install's onDone firing during these awaits removes its
    // own tag from the live map, which would invalidate this iteration.
    for (final sub in List.of(_installSubs.values)) {
      await sub.cancel();
    }
    _installSubs.clear();
    return super.close();
  }
}
