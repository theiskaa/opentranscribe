import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/theming/duo_theme.dart';
import 'package:opentranscribe/view/layouts/entry/screens/entry_detail_screen.dart';
import 'package:opentranscribe/view/widgets/formatting.dart';

void main() {
  setUpAll(initializeDateFormatting);

  final entry = Entry(
    id: 'entry',
    createdAt: DateTime(2026, 11, 15, 21, 35),
    audioPath: null,
    duration: const Duration(seconds: 5),
  );

  test('Duo untitled entries use time while the cover retains its date and time title', () {
    for (final locale in ['en', 'de', 'fr', 'it', 'ja', 'ko', 'pt', 'zh']) {
      expect(duoEntryTitle(entry, locale, inner: true), formatTime(entry.createdAt, locale));
      expect(duoEntryTitle(entry, locale, inner: false), entryDisplayTitle(entry, locale));
    }
  });

  test('a written title keeps its text on either display', () {
    final titled = entry.withTitle('A quiet evening');
    for (final inner in [true, false]) {
      expect(duoEntryTitle(titled, 'en', inner: inner), 'A quiet evening');
    }
  });

  test('short Duo prose grows until the long entry threshold', () {
    expect(duoBodyStyle(null), DuoTheme.shortBody);
    expect(duoBodyStyle('a' * 279), DuoTheme.shortBody);
    expect(duoBodyStyle('a' * 280), DuoTheme.body);
    expect(duoBodyStyle('a' * 2000), DuoTheme.body);
  });
}
