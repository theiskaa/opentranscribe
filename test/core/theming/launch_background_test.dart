import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/theming/app_theme.dart';

void main() {
  int component(Map<String, dynamic> colour, String channel) {
    final raw = (colour['components'] as Map<String, dynamic>)[channel] as String;
    if (raw.startsWith('0x') || raw.startsWith('0X')) return int.parse(raw);
    if (raw.contains('.')) return (double.parse(raw) * 255).round();
    return int.parse(raw);
  }

  int argbOf(Map<String, dynamic> entry) {
    final colour = entry['color'] as Map<String, dynamic>;
    expect(colour['color-space'], 'srgb');
    return component(colour, 'alpha') << 24 |
        component(colour, 'red') << 16 |
        component(colour, 'green') << 8 |
        component(colour, 'blue');
  }

  String? appearanceOf(Map<String, dynamic> entry) {
    final appearances = (entry['appearances'] as List?)?.cast<Map<String, dynamic>>() ?? const [];
    for (final appearance in appearances) {
      if (appearance['appearance'] == 'luminosity') return appearance['value'] as String;
    }
    return null;
  }

  List<Map<String, dynamic>> colours() {
    final file = File('ios/Runner/Assets.xcassets/LaunchBackground.colorset/Contents.json');
    return (jsonDecode(file.readAsStringSync())['colors'] as List).cast<Map<String, dynamic>>();
  }

  String storyboard(String name) =>
      File('ios/Runner/Base.lproj/$name.storyboard').readAsStringSync();

  test('the launch colorset holds exactly the default theme backgrounds', () {
    final entries = colours();
    expect(entries, hasLength(2));
    final light = entries.singleWhere((c) => appearanceOf(c) == null);
    final dark = entries.singleWhere((c) => appearanceOf(c) == 'dark');

    expect(argbOf(light), AppTheme.defaultLight.background.toARGB32());
    expect(argbOf(dark), AppTheme.defaultDark.background.toARGB32());
  });

  test('the launch and main storyboards both name that colorset as their background', () {
    final reference = RegExp(r'<color key="backgroundColor"[^>]*name="LaunchBackground"');
    for (final name in ['LaunchScreen', 'Main']) {
      expect(
        storyboard(name),
        matches(reference),
        reason: '$name.storyboard must not paint a colour of its own',
      );
    }
  });
}
