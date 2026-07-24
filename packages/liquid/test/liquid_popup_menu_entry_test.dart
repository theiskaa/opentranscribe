import 'package:flutter_test/flutter_test.dart';
import 'package:liquid/liquid.dart';

void main() {
  group('LiquidPopupButtonEntry', () {
    group('regular entry', () {
      test('creates with required fields', () {
        const entry = LiquidPopupButtonEntry(value: 'edit', label: 'Edit');

        expect(entry.value, 'edit');
        expect(entry.label, 'Edit');
        expect(entry.icon, isNull);
        expect(entry.children, isEmpty);
        expect(entry.isDivider, isFalse);
        expect(entry.causesNavigation, isFalse);
        expect(entry.isDestructive, isFalse);
      });

      test('creates with all optional fields', () {
        const entry = LiquidPopupButtonEntry(
          value: 'delete',
          label: 'Delete',
          icon: 'trash',
          isDestructive: true,
          causesNavigation: true,
        );

        expect(entry.value, 'delete');
        expect(entry.label, 'Delete');
        expect(entry.icon, 'trash');
        expect(entry.isDestructive, isTrue);
        expect(entry.causesNavigation, isTrue);
      });
    });

    group('.divider()', () {
      test('creates divider with correct values', () {
        const divider = LiquidPopupButtonEntry.divider();

        expect(divider.value, '__divider__');
        expect(divider.label, '');
        expect(divider.icon, isNull);
        expect(divider.children, isEmpty);
        expect(divider.isDivider, isTrue);
        expect(divider.causesNavigation, isFalse);
        expect(divider.isDestructive, isFalse);
      });
    });

    group('.submenu()', () {
      test('creates submenu with correct values', () {
        const children = [
          LiquidPopupButtonEntry(value: 'a', label: 'A'),
          LiquidPopupButtonEntry(value: 'b', label: 'B'),
        ];

        const submenu = LiquidPopupButtonEntry.submenu(label: 'More', children: children);

        expect(submenu.value, '__submenu__');
        expect(submenu.label, 'More');
        expect(submenu.children, hasLength(2));
        expect(submenu.isDivider, isFalse);
        expect(submenu.causesNavigation, isFalse);
        expect(submenu.isDestructive, isFalse);
      });

      test('submenu can have icon', () {
        const submenu = LiquidPopupButtonEntry.submenu(
          label: 'Options',
          icon: 'ellipsis',
          children: [LiquidPopupButtonEntry(value: 'x', label: 'X')],
        );

        expect(submenu.icon, 'ellipsis');
      });
    });

    group('toMap()', () {
      test('serializes regular entry', () {
        const entry = LiquidPopupButtonEntry(value: 'edit', label: 'Edit');
        final map = entry.toMap();

        expect(map['value'], 'edit');
        expect(map['label'], 'Edit');
        expect(map.containsKey('icon'), isFalse);
        expect(map.containsKey('children'), isFalse);
        expect(map.containsKey('isDivider'), isFalse);
        expect(map.containsKey('isDestructive'), isFalse);
      });

      test('serializes entry with icon', () {
        const entry = LiquidPopupButtonEntry(value: 'edit', label: 'Edit', icon: 'pencil');
        final map = entry.toMap();

        expect(map['icon'], 'pencil');
      });

      test('serializes destructive entry', () {
        const entry = LiquidPopupButtonEntry(value: 'delete', label: 'Delete', isDestructive: true);
        final map = entry.toMap();

        expect(map['isDestructive'], isTrue);
      });

      test('serializes divider', () {
        const divider = LiquidPopupButtonEntry.divider();
        final map = divider.toMap();

        expect(map['isDivider'], isTrue);
        expect(map['value'], '__divider__');
      });

      test('serializes entry with children', () {
        const entry = LiquidPopupButtonEntry.submenu(
          label: 'Sub',
          children: [
            LiquidPopupButtonEntry(value: 'a', label: 'A'),
            LiquidPopupButtonEntry(value: 'b', label: 'B'),
          ],
        );
        final map = entry.toMap();

        expect(map['children'], isA<List>());
        final children = map['children'] as List;
        expect(children, hasLength(2));
        expect((children[0] as Map)['value'], 'a');
        expect((children[1] as Map)['value'], 'b');
      });

      test('nested submenu serialization', () {
        const entry = LiquidPopupButtonEntry.submenu(
          label: 'Top',
          children: [
            LiquidPopupButtonEntry.submenu(
              label: 'Nested',
              children: [LiquidPopupButtonEntry(value: 'deep', label: 'Deep')],
            ),
          ],
        );
        final map = entry.toMap();

        final topChildren = map['children'] as List;
        final nestedMap = topChildren[0] as Map;
        expect(nestedMap['label'], 'Nested');

        final nestedChildren = nestedMap['children'] as List;
        expect((nestedChildren[0] as Map)['value'], 'deep');
      });
    });
  });
}
