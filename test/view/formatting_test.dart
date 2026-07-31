import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:opentranscribe/view/widgets/formatting.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting();
  });

  final thisYear = DateTime(2026, 7, 30);

  test('weekRangeLabel shares the month across a same-month week', () {
    // 2026-07-20 (Mon) .. 2026-07-26 (Sun)
    expect(weekRangeLabel(DateTime(2026, 7, 20), 'en_US', now: thisYear), 'Jul 20 – 26');
  });

  test('weekRangeLabel names both months across a month seam', () {
    // 2026-06-29 .. 2026-07-05
    expect(weekRangeLabel(DateTime(2026, 6, 29), 'en_US', now: thisYear), 'Jun 29 – Jul 5');
  });

  test('weekRangeLabel dates a week outside the current year', () {
    // Without the year, every past July would shadow this one's.
    expect(weekRangeLabel(DateTime(2025, 7, 21), 'en_US', now: thisYear), 'Jul 21 – Jul 27, 2025');
  });

  test('weekRangeLabel dates a week straddling the year seam', () {
    // The end's year pins the whole range; the start needs none of its own.
    expect(weekRangeLabel(DateTime(2025, 12, 29), 'en_US', now: thisYear), 'Dec 29 – Jan 4, 2026');
  });

  test('shortDateLabel adds the year only outside the current one', () {
    expect(shortDateLabel(DateTime(2026, 7, 27), 'en_US', now: thisYear), 'Jul 27');
    expect(shortDateLabel(DateTime(2025, 7, 27), 'en_US', now: thisYear), 'Jul 27, 2025');
  });

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

  test('formatBytes never renders 1000 of a unit at either seam', () {
    // Rounding reaches 1000 just under each threshold; the unit must step up
    // with the rounding, at the KB seam and the MB seam alike.
    expect(formatBytes(999500), '1.0 MB');
    expect(formatBytes(999999), '1.0 MB');
    expect(formatBytes(999940000), '999.9 MB');
    expect(formatBytes(999950000), '1.0 GB');
    expect(formatBytes(999999999), '1.0 GB');
  });

  test('formatBytes renders the decimal in the given locale', () {
    // The separator is the locale's, so sizes read like the rest of the app.
    expect(formatBytes(1500000, 'de'), '1,5 MB');
    expect(formatBytes(1500000, 'en'), '1.5 MB');
  });
}
