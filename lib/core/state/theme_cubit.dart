import 'dart:ui' show Brightness, PlatformDispatcher;

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/widgets.dart' show BuildContext, MediaQuery;
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/theming/app_motion.dart';
import 'package:opentranscribe/core/theming/app_theme.dart';
import 'package:opentranscribe/core/theming/app_theme_family.dart';
import 'package:opentranscribe/core/theming/app_theme_mode.dart';

/// The theme selection: a persisted family and mode over the platform
/// brightness. The family supplies the light/dark palettes; the mode picks
/// between them (following the platform for system).
@immutable
final class ThemeState {
  const ThemeState({required this.mode, required this.familyId, required this.platformBrightness});

  final AppThemeMode mode;
  final String familyId;
  final Brightness platformBrightness;

  AppThemeFamily get family => AppThemeFamily.byId(familyId);

  bool get wantDark =>
      mode == AppThemeMode.dark ||
      (mode == AppThemeMode.system && platformBrightness == Brightness.dark);

  /// The theme widgets actually render.
  AppTheme get resolved => family.resolve(wantDark: wantDark);

  ThemeState copyWith({AppThemeMode? mode, String? familyId, Brightness? platformBrightness}) =>
      ThemeState(
        mode: mode ?? this.mode,
        familyId: familyId ?? this.familyId,
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
          familyId: _storedFamily(storage),
          platformBrightness: platformBrightness ?? PlatformDispatcher.instance.platformBrightness,
        ),
      );

  static const key = 'theme.mode';
  static const familyKey = 'theme.family';

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

  /// An unknown or missing family falls back to the default one.
  static String _storedFamily(LocalService storage) {
    try {
      final raw = storage.readString(familyKey);
      return AppThemeFamily.all.any((f) => f.id == raw) ? raw! : AppThemeFamily.defaultId;
    } catch (_) {
      return AppThemeFamily.defaultId;
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

  /// Picks the theme family, KEEPING the current mode - so a family with "Match
  /// system" on still follows the platform (light uses light, dark uses dark).
  Future<void> setFamily(String familyId) async {
    await _storage.write(familyKey, familyId);
    if (isClosed) return;
    emit(state.copyWith(familyId: familyId));
  }

  /// OS appearance changed; only system mode visibly re-resolves.
  void updatePlatformBrightness(Brightness brightness) =>
      emit(state.copyWith(platformBrightness: brightness));
}

/// The one way widgets read tokens. Rebuilds the caller only when the resolved
/// theme object changes, not on every state emission.
extension ThemeX on BuildContext {
  AppTheme get theme => select<ThemeCubit, AppTheme>((cubit) => cubit.state.resolved);

  /// The OS "Reduce Motion" setting. A plain read (no select), so it is safe in
  /// callbacks and initState where [theme] would throw inside a lazy list. Each
  /// caller decides HOW to honor it; this only names the condition. iOS reports
  /// the setting on a dart:ui flag MediaQuery never surfaces; the root builder
  /// folds it into disableAnimations, so this read is truthful only below it.
  bool get reduceMotion => MediaQuery.disableAnimationsOf(this);

  /// Motion tokens without a select, for callbacks and settle logic. In build,
  /// prefer `theme.motion` so the widget re-themes when the theme changes.
  AppMotion get motionNow => read<ThemeCubit>().state.resolved.motion;

  /// The resolved theme without a select, for callbacks (a dialog's one-shot
  /// scrim read on open). In build, prefer [theme] so the widget re-themes.
  AppTheme get themeNow => read<ThemeCubit>().state.resolved;
}
