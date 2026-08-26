import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/app/launch_backdrop.dart';
import 'package:opentranscribe/core/theming/app_theme_family.dart';
import 'package:opentranscribe/core/theming/app_theme_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final defaultFamily = AppThemeFamily.byId(AppThemeFamily.defaultId);

  test('packs the mode and both palettes of the default family', () {
    final packed = launchBackdropOf(family: defaultFamily, mode: AppThemeMode.system);
    expect(packed, 'system,ffffffff,ff111111,ff111111,fff5f5f5');
  });

  test('an explicit mode packs its own name over the same palettes', () {
    final packed = launchBackdropOf(family: defaultFamily, mode: AppThemeMode.dark);
    expect(packed, startsWith('dark,'));
    expect(launchBackdropOf(family: defaultFamily, mode: AppThemeMode.light), startsWith('light,'));
    expect(
      packed.split(',').skip(1),
      launchBackdropOf(family: defaultFamily, mode: AppThemeMode.system).split(',').skip(1),
    );
  });

  test('a different family packs different colours', () {
    final gruvbox = launchBackdropOf(
      family: AppThemeFamily.byId(AppThemeFamily.gruvboxId),
      mode: AppThemeMode.system,
    );
    expect(gruvbox, isNot(launchBackdropOf(family: defaultFamily, mode: AppThemeMode.system)));
  });

  test('every colour is eight hex digits for the swift parser', () {
    for (final family in AppThemeFamily.all) {
      final parts = launchBackdropOf(family: family, mode: AppThemeMode.light).split(',');
      expect(parts, hasLength(5));
      for (final colour in parts.skip(1)) {
        expect(RegExp(r'^[0-9a-f]{8}$').hasMatch(colour), isTrue, reason: colour);
      }
    }
  });

  test('write stores the packed value under the launch backdrop key', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    final backdrop = LaunchBackdrop(prefs: SharedPreferences.getInstance());
    await backdrop.write(family: defaultFamily, mode: AppThemeMode.light);
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString(LaunchBackdrop.key),
      launchBackdropOf(family: defaultFamily, mode: AppThemeMode.light),
    );
  });
}
