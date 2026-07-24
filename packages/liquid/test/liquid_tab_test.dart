import 'package:flutter_test/flutter_test.dart';
import 'package:liquid/liquid.dart';

void main() {
  group('LiquidTab', () {
    test('toMap() serializes label', () {
      const tab = LiquidTab(label: 'Home');
      final map = tab.toMap();

      expect(map['label'], 'Home');
      expect(map.containsKey('icon'), isFalse);
      expect(map.containsKey('asset'), isFalse);
    });

    test('toMap() serializes with icon', () {
      const tab = LiquidTab(label: 'Settings', icon: 'gearshape');
      final map = tab.toMap();

      expect(map['label'], 'Settings');
      expect(map['icon'], 'gearshape');
      expect(map.containsKey('asset'), isFalse);
    });

    test('toMap() serializes with asset', () {
      const tab = LiquidTab(label: 'Menu', asset: 'tab_menu');
      final map = tab.toMap();

      expect(map['label'], 'Menu');
      expect(map['asset'], 'tab_menu');
      expect(map.containsKey('icon'), isFalse);
    });

    test('toMap() serializes with both icon and asset', () {
      const tab = LiquidTab(label: 'Tab', icon: 'house', asset: 'tab_home');
      final map = tab.toMap();

      expect(map['label'], 'Tab');
      expect(map['icon'], 'house');
      expect(map['asset'], 'tab_home');
    });

    test('toMap() uses empty string for null label', () {
      const tab = LiquidTab(icon: 'house');
      final map = tab.toMap();

      expect(map['label'], '');
    });
  });
}
