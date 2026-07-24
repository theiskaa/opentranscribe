import 'package:flutter_test/flutter_test.dart';
import 'package:liquid/liquid.dart';

void main() {
  group('LiquidPopupButtonEntry toMap serialization', () {
    test('regular entry toMap includes only set fields', () {
      const entry = LiquidPopupButtonEntry(value: 'v', label: 'L');
      final map = entry.toMap();

      expect(map.keys, containsAll(['value', 'label']));
      expect(map.containsKey('icon'), isFalse);
      expect(map.containsKey('isDivider'), isFalse);
      expect(map.containsKey('isDestructive'), isFalse);
      expect(map.containsKey('children'), isFalse);
    });

    test('divider toMap has isDivider true', () {
      const divider = LiquidPopupButtonEntry.divider();
      final map = divider.toMap();

      expect(map['isDivider'], isTrue);
      expect(map['value'], '__divider__');
      expect(map['label'], '');
    });

    test('entry with children serializes children', () {
      const entry = LiquidPopupButtonEntry.submenu(
        label: 'Group',
        children: [LiquidPopupButtonEntry(value: 'child1', label: 'C1')],
      );
      final map = entry.toMap();

      expect(map['children'], isA<List>());
      expect((map['children'] as List).length, 1);
    });

    test('isDestructive flag is serialized when true', () {
      const entry = LiquidPopupButtonEntry(value: 'del', label: 'Delete', isDestructive: true);
      final map = entry.toMap();

      expect(map['isDestructive'], isTrue);
    });

    test('isDestructive is not serialized when false', () {
      const entry = LiquidPopupButtonEntry(value: 'ok', label: 'OK');
      final map = entry.toMap();

      expect(map.containsKey('isDestructive'), isFalse);
    });
  });
}
