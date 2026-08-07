import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/view/layouts/home/components/entry_row.dart';

Entry entry(String id) =>
    Entry(id: id, createdAt: DateTime.utc(2026, 8, 3), audioPath: null, duration: Duration.zero);

void main() {
  group('newEntryIds (the entrance diff)', () {
    test('the first build marks nothing however full the journal', () {
      expect(newEntryIds(null, [entry('a'), entry('b')]), isEmpty);
    });

    test('an id the previous build had not seen is marked', () {
      expect(newEntryIds({'a'}, [entry('a'), entry('b')]), {'b'});
    });

    test('ids that merely left the list mark nothing', () {
      expect(newEntryIds({'a', 'b'}, [entry('a')]), isEmpty);
    });

    test('an unchanged list marks nothing', () {
      expect(newEntryIds({'a', 'b'}, [entry('a'), entry('b')]), isEmpty);
    });

    test('an id that left and returned is marked again', () {
      expect(newEntryIds(const {}, [entry('a')]), {'a'});
    });
  });

  group('newEntryDays (the splitter entrance diff)', () {
    test('the first build marks no days', () {
      expect(newEntryDays(null, {DateTime.utc(2026, 8, 3)}), isEmpty);
    });

    test('a day the previous build had not seen is marked', () {
      expect(
        newEntryDays(
          {DateTime.utc(2026, 8, 3)},
          {DateTime.utc(2026, 8, 3), DateTime.utc(2026, 8, 6)},
        ),
        {DateTime.utc(2026, 8, 6)},
      );
    });

    test('a day that merely left marks nothing', () {
      expect(
        newEntryDays(
          {DateTime.utc(2026, 8, 3), DateTime.utc(2026, 8, 6)},
          {DateTime.utc(2026, 8, 3)},
        ),
        isEmpty,
      );
    });
  });

  group('departedEntryDays (the splitter departure diff)', () {
    test('the first build marks no departures', () {
      expect(departedEntryDays(null, {DateTime.utc(2026, 8, 3)}), isEmpty);
    });

    test('a day the current build no longer holds is marked', () {
      expect(
        departedEntryDays(
          {DateTime.utc(2026, 8, 3), DateTime.utc(2026, 8, 6)},
          {DateTime.utc(2026, 8, 3)},
        ),
        {DateTime.utc(2026, 8, 6)},
      );
    });

    test('an arriving day marks nothing', () {
      expect(
        departedEntryDays(
          {DateTime.utc(2026, 8, 3)},
          {DateTime.utc(2026, 8, 3), DateTime.utc(2026, 8, 6)},
        ),
        isEmpty,
      );
    });
  });

  group('departingSplitterSlots (where a ghost folds)', () {
    test('a ghost newer than every section leads the list', () {
      final slots = departingSplitterSlots(
        sectionDays: [DateTime.utc(2026, 8, 3), DateTime.utc(2026, 8, 2)],
        departing: {DateTime.utc(2026, 8, 6)},
      );
      expect(slots, [
        [DateTime.utc(2026, 8, 6)],
        <DateTime>[],
        <DateTime>[],
      ]);
    });

    test('a ghost between two sections sits in their seam', () {
      final slots = departingSplitterSlots(
        sectionDays: [DateTime.utc(2026, 8, 6), DateTime.utc(2026, 8, 2)],
        departing: {DateTime.utc(2026, 8, 3)},
      );
      expect(slots, [
        <DateTime>[],
        [DateTime.utc(2026, 8, 3)],
        <DateTime>[],
      ]);
    });

    test('a ghost older than every section trails the list', () {
      final slots = departingSplitterSlots(
        sectionDays: [DateTime.utc(2026, 8, 6)],
        departing: {DateTime.utc(2026, 8, 2)},
      );
      expect(slots, [
        <DateTime>[],
        [DateTime.utc(2026, 8, 2)],
      ]);
    });

    test('ghosts sharing a seam order newest first', () {
      final slots = departingSplitterSlots(
        sectionDays: [DateTime.utc(2026, 8, 8)],
        departing: {DateTime.utc(2026, 8, 2), DateTime.utc(2026, 8, 3)},
      );
      expect(slots[1], [DateTime.utc(2026, 8, 3), DateTime.utc(2026, 8, 2)]);
    });

    test('with no sections every ghost trails', () {
      final slots = departingSplitterSlots(
        sectionDays: const [],
        departing: {DateTime.utc(2026, 8, 3)},
      );
      expect(slots, [
        [DateTime.utc(2026, 8, 3)],
      ]);
    });

    test('a ghost sharing a live day folds above that section', () {
      final slots = departingSplitterSlots(
        sectionDays: [DateTime.utc(2026, 8, 3)],
        departing: {DateTime.utc(2026, 8, 3)},
      );
      expect(slots, [
        [DateTime.utc(2026, 8, 3)],
        <DateTime>[],
      ]);
    });
  });

  group('allDying (what layout treats as already gone)', () {
    test('true only when every id is mid-exit', () {
      expect(allDying(['a', 'b'], {'a', 'b'}), isTrue);
      expect(allDying(['a', 'b'], {'a'}), isFalse);
    });

    test('a living survivor keeps the group alive whatever dies around it', () {
      expect(allDying(['a', 'b', 'c'], {'a', 'c'}), isFalse);
    });

    test('no ids means gone, so an untouched leading section still leads', () {
      expect(allDying(const [], {'a'}), isTrue);
      expect(allDying(const [], const {}), isTrue);
    });
  });
}
