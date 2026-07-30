import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:opentranscribe/view/layouts/reflections/components/reflection_row.dart';

/// The week-range label is the one bit of real logic in the row; the widget
/// itself is not pumped (no widget tests).
void main() {
  setUpAll(() async {
    await initializeDateFormatting();
  });

  test('a same-month week shares the month across the range', () {
    // 2026-07-20 (Mon) .. 2026-07-26 (Sun)
    expect(weekRangeLabel(DateTime(2026, 7, 20), 'en_US'), 'Jul 20 – 26');
  });

  test('a cross-month week names both months', () {
    // 2026-06-29 .. 2026-07-05
    expect(weekRangeLabel(DateTime(2026, 6, 29), 'en_US'), 'Jun 29 – Jul 5');
  });
}
