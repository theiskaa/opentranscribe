import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_theme.dart';
import 'package:opentranscribe/core/theming/app_theme_family.dart';
import 'package:opentranscribe/core/theming/app_theme_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const key = 'test-encryption-key-0123456789ab';
  late LocalService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalService();
    await storage.init(encryptionKey: key);
  });

  ThemeCubit build({Brightness brightness = Brightness.light}) =>
      ThemeCubit(storage: storage, platformBrightness: brightness);

  test('resolution matrix: mode wins, system follows brightness', () {
    final cubit = build();
    for (final (mode, brightness, expected) in [
      (AppThemeMode.light, Brightness.dark, AppTheme.defaultLight),
      (AppThemeMode.dark, Brightness.light, AppTheme.defaultDark),
      (AppThemeMode.system, Brightness.light, AppTheme.defaultLight),
      (AppThemeMode.system, Brightness.dark, AppTheme.defaultDark),
    ]) {
      final state = cubit.state.copyWith(mode: mode, platformBrightness: brightness);
      expect(state.resolved, same(expected), reason: '$mode / $brightness');
    }
  });

  test('defaults to system mode with nothing stored', () {
    expect(build().state.mode, AppThemeMode.system);
  });

  test('setMode persists and a fresh cubit on the same storage reads it', () async {
    await build().setMode(AppThemeMode.dark);
    expect(build().state.mode, AppThemeMode.dark);
  });

  test('an unknown stored value falls back to system', () async {
    await storage.write(ThemeCubit.key, 'sepia');
    expect(build().state.mode, AppThemeMode.system);
  });

  test('an undecryptable stored value falls back to system', () async {
    await build().setMode(AppThemeMode.dark);
    // Reopen the same prefs under a different key: the stored mode no longer
    // decrypts and the boot read must not throw.
    final other = LocalService();
    await other.init(encryptionKey: 'a-completely-different-key-000000');
    expect(
      ThemeCubit(storage: other, platformBrightness: Brightness.light).state.mode,
      AppThemeMode.system,
    );
  });

  test('a failing persist applies nothing', () async {
    // An empty encryption key makes every encrypting write throw.
    final broken = LocalService();
    await broken.init(encryptionKey: '');
    final cubit = ThemeCubit(storage: broken, platformBrightness: Brightness.light);

    await expectLater(cubit.setMode(AppThemeMode.dark), throwsA(anything));
    expect(cubit.state.mode, AppThemeMode.system);
  });

  test('brightness change re-resolves only in system mode', () async {
    final cubit = build();
    cubit.updatePlatformBrightness(Brightness.dark);
    expect(cubit.state.resolved, same(AppTheme.defaultDark));

    await cubit.setMode(AppThemeMode.light);
    cubit.updatePlatformBrightness(Brightness.dark);
    expect(cubit.state.resolved, same(AppTheme.defaultLight));
  });

  test('defaults to the default family with nothing stored', () {
    expect(build().state.familyId, AppThemeFamily.defaultId);
  });

  test('setFamily persists and keeps the current mode', () async {
    final cubit = build();
    await cubit.setMode(AppThemeMode.dark);
    await cubit.setFamily(AppThemeFamily.gruvboxId);
    expect(cubit.state.mode, AppThemeMode.dark, reason: 'mode must be preserved');

    final fresh = build();
    expect(fresh.state.familyId, AppThemeFamily.gruvboxId);
    expect(fresh.state.mode, AppThemeMode.dark);
    expect(fresh.state.resolved, same(AppThemeFamily.byId(AppThemeFamily.gruvboxId).dark));
  });

  test('an unknown stored family falls back to the default family', () async {
    await storage.write(ThemeCubit.familyKey, 'dracula');
    expect(build().state.familyId, AppThemeFamily.defaultId);
  });
}
