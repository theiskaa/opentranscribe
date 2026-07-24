import 'package:flutter_test/flutter_test.dart';

import 'package:opentranscribe/view/widgets/rolling_text.dart';

void main() {
  group('rollingSlots', () {
    test('equal strings produce only static slots', () {
      final slots = rollingSlots('July 24', 'July 24');
      expect(slots.map((s) => s.char).join(), 'July 24');
      expect(slots.any((s) => s.rolls), isFalse);
    });

    test('only differing characters roll', () {
      final slots = rollingSlots('July 24', 'July 19');
      expect(slots.map((s) => s.char).join(), 'July 19');
      expect(
        [for (final s in slots) s.rolls],
        [
          false, false, false, false, false, // 'July '
          true, true, // '24' -> '19'
        ],
      );
    });

    test('growth rolls the new tail in', () {
      final slots = rollingSlots('June 9', 'June 30');
      expect(slots.length, 7);
      expect(slots[5], (char: '3', rolls: true));
      expect(slots[6], (char: '0', rolls: true));
      expect(slots.sublist(0, 5).any((s) => s.rolls), isFalse);
    });

    test('shrinkage rolls the dropped tail out as empty', () {
      final slots = rollingSlots('June 30', 'June 9');
      expect(slots.length, 7);
      expect(slots[5], (char: '9', rolls: true));
      expect(slots[6], (char: '', rolls: true));
    });

    test('empty edges', () {
      expect(rollingSlots('', ''), isEmpty);
      expect(rollingSlots('', 'ab'), [(char: 'a', rolls: true), (char: 'b', rolls: true)]);
      expect(rollingSlots('ab', ''), [(char: '', rolls: true), (char: '', rolls: true)]);
    });
  });
}
