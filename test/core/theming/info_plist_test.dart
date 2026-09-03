import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the iPhone build allows portrait and nothing else', () {
    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    final match = RegExp(
      r'<key>UISupportedInterfaceOrientations</key>\s*<array>(.*?)</array>',
      dotAll: true,
    ).firstMatch(plist);
    expect(match, isNotNull);
    final orientations = RegExp(
      r'<string>(.*?)</string>',
    ).allMatches(match!.group(1)!).map((m) => m.group(1)).toList();
    expect(orientations, ['UIInterfaceOrientationPortrait']);
  });
}
