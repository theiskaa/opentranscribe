import 'package:flutter_test/flutter_test.dart';

import 'package:opentranscribe/view/layouts/home/components/section_tracker.dart';

void main() {
  group('viewedDayAt', () {
    final jul23 = DateTime(2026, 7, 23);
    final jul22 = DateTime(2026, 7, 22);
    final jul20 = DateTime(2026, 7, 20);
    // Splitter label starts in scroll space, deliberately unordered: the
    // accumulated map carries no order.
    final starts = [(600.0, jul22), (203.0, jul23), (1100.0, jul20)];
    const line = 190.0;

    test('no sections is always today', () {
      expect(viewedDayAt(500, line, const [], null), isNull);
    });

    test('home is today, and so is an overscroll past it', () {
      expect(viewedDayAt(0, line, starts, null), isNull);
      expect(viewedDayAt(-30, line, starts, jul23), isNull);
    });

    test('the home boundary is held from both sides', () {
      // Coming from today the first label must clear the deadband to take the
      // bar, so a nudge of a few pixels cannot hand it over.
      expect(viewedDayAt(12, line, starts, null), isNull);
      expect(viewedDayAt(13, line, starts, null), jul23);
      // Coming back, the day keeps it until the list is actually at rest, so
      // the same few pixels cannot hand it back.
      expect(viewedDayAt(1, line, starts, jul23), jul23);
      expect(viewedDayAt(0, line, starts, jul23), isNull);
    });

    test('a day takes the title the moment its label reaches the line', () {
      // jul23's label starts at 203, so it lands on the line at offset 13.
      expect(viewedDayAt(12.9, line, starts, null), isNull);
      expect(viewedDayAt(13, line, starts, null), jul23);
      // jul22 starts at 600: it lands at 410.
      expect(viewedDayAt(409, line, starts, jul23), jul23);
      expect(viewedDayAt(410, line, starts, jul23), jul22);
    });

    test('a day parked on the line answers from geometry alone', () {
      // What a calendar tap does: offset = start - line. No holder hint needed,
      // so the tapped day cannot flip back on arrival.
      expect(viewedDayAt(410, line, starts, null), jul22);
      expect(viewedDayAt(910, line, starts, null), jul20);
    });

    test('the holder keeps the title until its label falls a deadband back', () {
      expect(viewedDayAt(398, line, starts, jul22), jul22);
      expect(viewedDayAt(397, line, starts, jul22), jul23);
      // The hold is what the deadband buys: geometry alone gives the day above.
      expect(viewedDayAt(398, line, starts, null), jul23);
    });

    test('a wider deadband widens the hold window', () {
      expect(viewedDayAt(360, line, starts, jul22, deadband: 50), jul22);
      expect(viewedDayAt(359, line, starts, jul22, deadband: 50), jul23);
    });

    test('deep offsets stay on the last section', () {
      expect(viewedDayAt(5000, line, starts, null), jul20);
    });
  });
}
