import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/theming/app_theme.dart';

void main() {
  int component(Map<String, dynamic> colour, String channel) =>
      int.parse((colour['components'] as Map<String, dynamic>)[channel] as String);

  int argbOf(Map<String, dynamic> entry) {
    final colour = entry['color'] as Map<String, dynamic>;
    return 0xFF000000 |
        component(colour, 'red') << 16 |
        component(colour, 'green') << 8 |
        component(colour, 'blue');
  }

  test('the launch screen paints the same backgrounds the default theme does', () {
    final file = File('ios/Runner/Assets.xcassets/LaunchBackground.colorset/Contents.json');
    final colours = (jsonDecode(file.readAsStringSync())['colors'] as List)
        .cast<Map<String, dynamic>>();
    final dark = colours.firstWhere((c) => c.containsKey('appearances'));
    final light = colours.firstWhere((c) => !c.containsKey('appearances'));

    expect(argbOf(light), AppTheme.defaultLight.background.toARGB32());
    expect(argbOf(dark), AppTheme.defaultDark.background.toARGB32());
  });
}
