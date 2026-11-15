import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/view/layouts/settings/components/strip_chip.dart';

void main() {
  test('a download with no fraction yet shows the loader rather than an empty ring', () {
    expect(chipProgressWaits(0), isTrue);
  });

  test('a download under way shows its ring', () {
    expect(chipProgressWaits(0.4), isFalse);
  });

  test('a preparing tail shows the loader, since its full ring would read as stalled', () {
    expect(chipProgressWaits(1, preparing: true), isTrue);
  });
}
