import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/notify/nudge_schedule.dart';
import 'package:reflections/reflections.dart';

void main() {
  final sundayEvening = DateTime(2026, 11, 15, 20, 30);

  group('nextNudge (what the reminder switch says comes next)', () {
    test('a daily nudge already past today lands tomorrow', () {
      final next = nextNudge(
        now: sundayEvening,
        hour: 9,
        minute: 0,
        periods: const [ReflectionPeriod.daily],
        weekStart: DateTime.monday,
      );
      expect(next, DateTime(2026, 11, 16, 9));
    });

    test('a daily nudge still ahead today lands today', () {
      final next = nextNudge(
        now: sundayEvening,
        hour: 21,
        minute: 0,
        periods: const [ReflectionPeriod.daily],
        weekStart: DateTime.monday,
      );
      expect(next, DateTime(2026, 11, 15, 21));
    });

    test('a weekly nudge lands on the first day of the locale\'s week', () {
      final monday = nextNudge(
        now: sundayEvening,
        hour: 9,
        minute: 0,
        periods: const [ReflectionPeriod.weekly],
        weekStart: DateTime.monday,
      );
      final sunday = nextNudge(
        now: sundayEvening,
        hour: 9,
        minute: 0,
        periods: const [ReflectionPeriod.weekly],
        weekStart: DateTime.sunday,
      );
      expect(monday, DateTime(2026, 11, 16, 9));
      expect(sunday, DateTime(2026, 11, 22, 9));
    });

    test('a monthly nudge lands on the 1st of the next month', () {
      final next = nextNudge(
        now: sundayEvening,
        hour: 9,
        minute: 0,
        periods: const [ReflectionPeriod.monthly],
        weekStart: DateTime.monday,
      );
      expect(next, DateTime(2026, 12, 1, 9));
    });

    test('with several periods the earliest of them comes next', () {
      final next = nextNudge(
        now: sundayEvening,
        hour: 9,
        minute: 0,
        periods: const [ReflectionPeriod.weekly, ReflectionPeriod.monthly],
        weekStart: DateTime.monday,
      );
      expect(next, DateTime(2026, 11, 16, 9));
    });

    test('no period to nudge for means nothing comes next', () {
      final next = nextNudge(
        now: sundayEvening,
        hour: 9,
        minute: 0,
        periods: const [],
        weekStart: DateTime.monday,
      );
      expect(next, isNull);
    });
  });

  group('nextNudge at the edges', () {
    test('a nudge due this very minute is already past, so the next is tomorrow', () {
      final next = nextNudge(
        now: DateTime(2026, 11, 15, 9),
        hour: 9,
        minute: 0,
        periods: const [ReflectionPeriod.daily],
        weekStart: DateTime.monday,
      );
      expect(next, DateTime(2026, 11, 16, 9));
    });

    test('a monthly nudge in December lands on the 1st of January', () {
      final next = nextNudge(
        now: DateTime(2026, 12, 2, 10),
        hour: 9,
        minute: 0,
        periods: const [ReflectionPeriod.monthly],
        weekStart: DateTime.monday,
      );
      expect(next, DateTime(2027, 1, 1, 9));
    });

    test('a week starting on Sunday nudges today when today is Sunday and the time is ahead', () {
      final next = nextNudge(
        now: DateTime(2026, 11, 15, 8),
        hour: 9,
        minute: 0,
        periods: const [ReflectionPeriod.weekly],
        weekStart: DateTime.sunday,
      );
      expect(next, DateTime(2026, 11, 15, 9));
    });
  });

  group('nudgeDayOf (how the next nudge\'s day reads)', () {
    test('later the same day reads as today', () {
      expect(nudgeDayOf(sundayEvening, DateTime(2026, 11, 15, 21)), NudgeDay.today);
    });

    test('the next calendar day reads as tomorrow', () {
      expect(nudgeDayOf(sundayEvening, DateTime(2026, 11, 16, 9)), NudgeDay.tomorrow);
    });

    test('a day shortened by a clock change still reads as tomorrow, not today', () {
      expect(nudgeDayOf(DateTime(2026, 3, 8, 20, 30), DateTime(2026, 3, 9, 9)), NudgeDay.tomorrow);
    });

    test('two days on reads as a date', () {
      expect(nudgeDayOf(sundayEvening, DateTime(2026, 11, 17, 9)), NudgeDay.later);
    });
  });
}
