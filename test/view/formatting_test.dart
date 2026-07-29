import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/view/widgets/formatting.dart';

void main() {
  test('formatBytes uses decimal units and whole numbers below a megabyte', () {
    expect(formatBytes(0), '0 B');
    expect(formatBytes(999), '999 B');
    expect(formatBytes(1000), '1 KB');
    expect(formatBytes(250000), '250 KB');
    expect(formatBytes(999499), '999 KB');
  });

  test('formatBytes shows one decimal from a megabyte up', () {
    expect(formatBytes(1000000), '1.0 MB');
    expect(formatBytes(14400000), '14.4 MB');
    expect(formatBytes(1230000000), '1.2 GB');
  });

  test('formatBytes renders the decimal in the given locale', () {
    // The separator is the locale's, so sizes read like the rest of the app.
    expect(formatBytes(1500000, 'de'), '1,5 MB');
    expect(formatBytes(1500000, 'en'), '1.5 MB');
  });
}
