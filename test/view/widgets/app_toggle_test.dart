import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/view/widgets/app_toggle.dart';

void main() {
  group('what a tap commits', () {
    test('a tap away from the parent value commits', () {
      expect(toggleCommits(target: true, held: null, value: false), isTrue);
    });

    test('a tap onto the parent value only settles the knob', () {
      expect(toggleCommits(target: false, held: null, value: false), isFalse);
    });

    test('a second tap while the first is held reads the held value, not the stale one', () {
      expect(toggleCommits(target: false, held: true, value: false), isTrue);
      expect(toggleCommits(target: true, held: true, value: false), isFalse);
    });
  });

  group('when the knob follows the parent', () {
    test('with nothing held, an outside flip glides the knob to it', () {
      expect(toggleFollows(held: null, value: true), isTrue);
    });

    test('a late echo of the held commit leaves the knob on its own spring', () {
      expect(toggleFollows(held: true, value: true), isFalse);
    });

    test('a hold that ran out with the parent unmoved springs the knob back', () {
      expect(toggleFollows(held: true, value: false), isTrue);
    });
  });
}
