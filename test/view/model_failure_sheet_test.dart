import 'package:flutter_test/flutter_test.dart';

import 'package:opentranscribe/core/state/settings_cubit.dart';
import 'package:opentranscribe/view/layouts/settings/components/model_failure_sheet.dart';
import 'package:transcriber/transcriber.dart';

void main() {
  LanguageModelState row({required String tag, bool reserved = true}) => LanguageModelState(
    tag: tag,
    status: ModelAssetStatus.supported,
    reserved: reserved,
    isDefault: false,
  );

  const blocked = LanguageModelState(
    tag: 'fr-FR',
    status: ModelAssetStatus.supported,
    reserved: false,
    isDefault: false,
    failure: LanguageFailure(
      kind: LanguageFailureKind.capReached,
      reservedTags: ['en-US', 'de-DE', 'it-IT', 'fr-FR'],
    ),
  );

  SettingsState state(List<LanguageModelState> rows) =>
      SettingsState(localeId: 'en-US', languages: rows);

  group('evictableLanguages', () {
    test('offers the other slot-holders, never the blocked language itself', () {
      final s = state([row(tag: 'en-US'), row(tag: 'de-DE'), row(tag: 'it-IT'), blocked]);
      expect(evictableLanguages(blocked, s), ['de-DE', 'it-IT']);
    });

    test('never offers the current default', () {
      final s = state([row(tag: 'en-US'), row(tag: 'de-DE'), blocked]);
      expect(evictableLanguages(blocked, s), isNot(contains('en-US')));
    });

    test('a slot freed since the cap fired is not offered again', () {
      final s = state([row(tag: 'en-US'), row(tag: 'de-DE'), row(tag: 'it-IT', reserved: false)]);
      expect(evictableLanguages(blocked, s), ['de-DE']);
    });

    test('every holder disqualified leaves the list empty for the retry action', () {
      final s = state([row(tag: 'en-US'), row(tag: 'it-IT', reserved: false)]);
      expect(evictableLanguages(blocked, s), isEmpty);
    });
  });
}
