import 'dart:ui' show Brightness, PlatformDispatcher;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/widgets.dart' show BuildContext;
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/theming/app_theme.dart';
import 'package:opentranscribe/core/theming/app_theme_mode.dart';

/// The theme selection: a persisted mode over the built-in light/dark pair,
/// tracking the platform brightness for system mode.
@immutable
final class ThemeState {
  const ThemeState({
    required this.mode,
    required this.light,
    required this.dark,
    required this.platformBrightness,
  });

  final AppThemeMode mode;
  final AppTheme light;
  final AppTheme dark;
  final Brightness platformBrightness;

  /// The theme widgets actually render.
  AppTheme get resolved => switch (mode) {
    AppThemeMode.light => light,
    AppThemeMode.dark => dark,
    AppThemeMode.system => platformBrightness == Brightness.dark ? dark : light,
  };

  ThemeState copyWith({AppThemeMode? mode, Brightness? platformBrightness}) => ThemeState(
    mode: mode ?? this.mode,
    light: light,
    dark: dark,
    platformBrightness: platformBrightness ?? this.platformBrightness,
  );
}

/// Owns theme resolution and mode persistence. The root widget pushes platform
/// brightness changes in; everything else reads `context.theme`.
class ThemeCubit extends Cubit<ThemeState> {
  ThemeCubit({required LocalService storage, Brightness? platformBrightness})
    : _storage = storage,
      super(
        ThemeState(
          mode: _storedMode(storage),
          light: AppTheme.defaultLight,
          dark: AppTheme.defaultDark,
          platformBrightness: platformBrightness ?? PlatformDispatcher.instance.platformBrightness,
        ),
      );

  static const key = 'theme.mode';

  final LocalService _storage;

  /// Unknown or undecryptable values fail safe to system, like the other
  /// settings readers: a settings read must never throw at boot.
  static AppThemeMode _storedMode(LocalService storage) {
    try {
      final raw = storage.readString(key);
      return AppThemeMode.values.firstWhere(
        (mode) => mode.name == raw,
        orElse: () => AppThemeMode.system,
      );
    } catch (_) {
      return AppThemeMode.system;
    }
  }

  /// Persists first and applies nothing on failure, so storage and state can
  /// never disagree after a relaunch.
  Future<void> setMode(AppThemeMode mode) async {
    await _storage.write(key, mode.name);
    // The await can outlive the cubit during app teardown.
    if (isClosed) return;
    emit(state.copyWith(mode: mode));
  }

  /// OS appearance changed; only system mode visibly re-resolves.
  void updatePlatformBrightness(Brightness brightness) =>
      emit(state.copyWith(platformBrightness: brightness));
}

/// The one way widgets read tokens. Rebuilds the caller only when the resolved
/// theme object changes, not on every state emission.
extension ThemeX on BuildContext {
  AppTheme get theme => select<ThemeCubit, AppTheme>((cubit) => cubit.state.resolved);
}
