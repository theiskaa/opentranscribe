import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/view/layouts/settings/components/strip_chip.dart';

void main() {
  test('a download with no fraction yet spins rather than showing an empty ring', () {
    expect(chipProgressSpins(0), isTrue);
  });

  test('a download under way shows its ring', () {
    expect(chipProgressSpins(0.4), isFalse);
  });

  test('a preparing tail spins, its full ring would read as stalled', () {
    expect(chipProgressSpins(1, preparing: true), isTrue);
  });
}
