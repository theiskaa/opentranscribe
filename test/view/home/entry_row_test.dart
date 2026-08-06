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
}
