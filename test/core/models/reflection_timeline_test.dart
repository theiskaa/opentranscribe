import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/models/reflection.dart';
import 'package:opentranscribe/core/models/reflection_timeline.dart';
import 'package:opentranscribe/core/reflect/reflection_period.dart';

void main() {
  final currentWeek = DateTime(2026, 7, 27);
  final lastWeek = DateTime(2026, 7, 20);
  final twoWeeksAgo = DateTime(2026, 7, 13);
  final threeWeeksAgo = DateTime(2026, 7, 6);
  final oldFloor = DateTime(2026, 6, 8);

  Reflection stored(DateTime week, {String? text}) =>
      Reflection(weekStart: week, generatedAt: DateTime.utc(2026, 7, 27), text: text);

  List<ReflectionWeek> timeline({
    List<Reflection> history = const [],
    Set<DateTime> journaled = const {},
    List<DateTime> deleted = const [],
    DateTime? floor,
  }) => reflectionTimeline(
    period: ReflectionPeriod.weekly,
    history: history,
    journaledStarts: journaled,
    deletedStarts: deleted,
    floor: floor ?? oldFloor,
    currentStart: currentWeek,
  );

  test('orders oldest first, so the last page is the newest closed week', () {
    final weeks = timeline(
      history: [
        stored(lastWeek, text: 'new'),
        stored(threeWeeksAgo, text: 'old'),
      ],
    );
    expect(weeks.map((w) => w.weekStart), [threeWeeksAgo, lastWeek]);
  });

  test('the open week is never a page, whatever claims it', () {
    final weeks = timeline(
      history: [stored(currentWeek, text: 'should not exist')],
      journaled: {currentWeek},
      deleted: [currentWeek],
    );
    expect(weeks, isEmpty);
  });

  test('a stored silence and a stored text carry their own statuses', () {
    final weeks = timeline(
      history: [
        stored(lastWeek, text: 'x'),
        stored(twoWeeksAgo),
      ],
    );
    expect(weeks.map((w) => w.status), [
      ReflectionWeekStatus.silent,
      ReflectionWeekStatus.reflected,
    ]);
    expect(weeks.last.reflection!.text, 'x');
  });

  test('a journaled week with nothing stored waits, and only above the floor', () {
    final weeks = timeline(journaled: {lastWeek, threeWeeksAgo}, floor: twoWeeksAgo);
    expect(weeks.map((w) => w.weekStart), [lastWeek]);
    expect(weeks.single.status, ReflectionWeekStatus.unreflected);
  });

  test('a null floor (catch-up never ran) yields no waiting pages at all', () {
    final weeks = reflectionTimeline(
      period: ReflectionPeriod.weekly,
      history: [],
      journaledStarts: {lastWeek},
      deletedStarts: const [],
      floor: null,
      currentStart: currentWeek,
    );
    expect(weeks, isEmpty);
  });

  test('a stored reflection below the floor still gets its page (dev devices)', () {
    final belowFloor = DateTime(2026, 5, 4);
    final weeks = timeline(history: [stored(belowFloor, text: 'kept')]);
    expect(weeks.single.status, ReflectionWeekStatus.reflected);
  });

  test('a tombstone is an erased page, outranked by a stored row, outranking journaled', () {
    final weeks = timeline(
      history: [stored(lastWeek, text: 'row wins')],
      journaled: {lastWeek, twoWeeksAgo},
      deleted: [lastWeek, twoWeeksAgo],
    );
    expect(weeks.map((w) => w.status), [
      ReflectionWeekStatus.erased,
      ReflectionWeekStatus.reflected,
    ]);
  });

  test('two tombstones left overlapping by a first-day shift collapse to one erased page', () {
    final sundayWeek = DateTime(2026, 7, 19);
    final weeks = timeline(deleted: [sundayWeek, lastWeek]);
    expect(weeks.single.weekStart, sundayWeek);
    expect(weeks.single.status, ReflectionWeekStatus.erased);
  });

  test('a below-floor tombstone still earns its erased page, '
      'since the floor gates only waiting pages', () {
    final belowFloor = DateTime(2026, 5, 4);
    final weeks = timeline(deleted: [belowFloor]);
    expect(weeks.single.status, ReflectionWeekStatus.erased);
  });

  test('a first-day shift cannot page the same week twice', () {
    final sundayWeek = DateTime(2026, 7, 19);
    final weeks = timeline(
      history: [stored(sundayWeek, text: 'x')],
      journaled: {lastWeek},
    );
    expect(weeks.length, 1);
    expect(weeks.single.weekStart, sundayWeek);
  });

  test('pageForWeek answers the index, the last page for absent or null, -1 for empty', () {
    final weeks = timeline(
      history: [
        stored(lastWeek, text: 'a'),
        stored(twoWeeksAgo, text: 'b'),
      ],
    );
    expect(pageForWeek(weeks, twoWeeksAgo), 0);
    expect(pageForWeek(weeks, lastWeek), 1);
    expect(pageForWeek(weeks, null), 1);
    expect(pageForWeek(weeks, DateTime(2020, 1, 6)), 1);
    expect(pageForWeek(const [], null), -1);
  });
}
