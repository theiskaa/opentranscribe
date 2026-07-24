import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/services/audio_storage_settings.dart';
import 'package:opentranscribe/core/services/transcription_service.dart';
import 'package:opentranscribe/core/services/transcription_settings.dart';
import 'package:opentranscribe/core/transcribe/transcription_engine.dart';

/// What the settings screen renders about the transcription and storage
/// backbone.
@immutable
final class SettingsState {
  const SettingsState({
    this.localeId = '',
    this.supportedLocales = const [],
    this.modelInstalled = false,
    this.availability,
    this.installProgress,
    this.installFailed = false,
    this.backupExcluded = true,
  });

  final String localeId;
  final List<String> supportedLocales;
  final bool modelInstalled;
  final Availability? availability;

  /// 0..1 while a model download runs; null otherwise.
  final double? installProgress;
  final bool installFailed;
  final bool backupExcluded;

  bool get installing => installProgress != null;

  SettingsState copyWith({
    String? localeId,
    List<String>? supportedLocales,
    bool? modelInstalled,
    Availability? availability,
    double? installProgress,
    bool clearInstallProgress = false,
    bool? installFailed,
    bool? backupExcluded,
  }) => SettingsState(
    localeId: localeId ?? this.localeId,
    supportedLocales: supportedLocales ?? this.supportedLocales,
    modelInstalled: modelInstalled ?? this.modelInstalled,
    availability: availability ?? this.availability,
    installProgress: clearInstallProgress ? null : (installProgress ?? this.installProgress),
    installFailed: installFailed ?? this.installFailed,
    backupExcluded: backupExcluded ?? this.backupExcluded,
  );
}

/// Drives the settings screen over the idle backbone: language, model
/// readiness and installation, and the backup preference. Theme mode and app
/// language live elsewhere (ThemeCubit, AppLanguage).
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
    unawaited(load());
  }

  final TranscriptionService _service;
  final TranscriptionSettings _transcription;
  final AudioStorageSettings _audioStorage;
  StreamSubscription<ModelInstallProgress>? _installSub;
  int _loadGeneration = 0;

  Future<void> load() async {
    // Overlapping loads (a rapid locale double-pick) must not let the older
    // one land last and revert the newer state.
    final generation = ++_loadGeneration;
    final localeId = _transcription.localeId;
    final supported = await _service.supportedLocales();
    final installed = await _service.isModelInstalled();
    final availability = await _service.checkAvailability();
    if (isClosed || generation != _loadGeneration) return;
    emit(
      state.copyWith(
        localeId: localeId,
        supportedLocales: supported,
        modelInstalled: installed,
        availability: availability,
        backupExcluded: _audioStorage.backupExcluded,
      ),
    );
  }

  /// Persists the transcription language and re-reads per-locale readiness.
  Future<void> setLocale(String tag) async {
    await _transcription.setLocaleId(tag);
    await load();
  }

  /// Downloads the model for the current language. Single-flight is the
  /// engine contract's caller promise, so a second tap while one runs is a
  /// no-op.
  void install() {
    if (state.installing) return;
    emit(state.copyWith(installProgress: 0, installFailed: false));
    _installSub = _service.installModel().listen(
      (progress) {
        if (progress.done) return;
        emit(state.copyWith(installProgress: progress.fraction));
      },
      onDone: () {
        _installSub = null;
        emit(state.copyWith(clearInstallProgress: true));
        unawaited(load());
      },
      onError: (Object _) {
        _installSub = null;
        emit(state.copyWith(clearInstallProgress: true, installFailed: true));
      },
    );
  }

  Future<void> setBackupExcluded(bool excluded) async {
    await _audioStorage.setExcluded(excluded);
    if (isClosed) return;
    emit(state.copyWith(backupExcluded: _audioStorage.backupExcluded));
  }

  @override
  Future<void> close() async {
    await _installSub?.cancel();
    return super.close();
  }
}
