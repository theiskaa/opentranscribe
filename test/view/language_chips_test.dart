import 'package:flutter_test/flutter_test.dart';

import 'package:opentranscribe/core/state/settings_cubit.dart';
import 'package:opentranscribe/view/layouts/settings/components/language_chips.dart';
import 'package:transcriber/transcriber.dart';

void main() {
  LanguageModelState row({
    String tag = 'en-US',
    ModelAssetStatus status = ModelAssetStatus.supported,
    bool reserved = false,
    bool isDefault = false,
    LanguageFailure? failure,
    double? installFraction,
  }) => LanguageModelState(
    tag: tag,
    status: status,
    reserved: reserved,
    isDefault: isDefault,
    failure: failure,
    installFraction: installFraction,
  );

  group('chipLanguages', () {
    test('a ready non-default language earns a chip', () {
      final rows = [row(status: ModelAssetStatus.installed, reserved: true)];
      expect(chipLanguages(rows, oneModelForAll: false), rows);
    });

    test('under one model for every language nothing earns a chip', () {
      final rows = [row(status: ModelAssetStatus.installed, reserved: true)];
      expect(chipLanguages(rows, oneModelForAll: true), isEmpty);
    });

    test('the default never wears a chip, the hero carries it', () {
      final rows = [row(status: ModelAssetStatus.installed, reserved: true, isDefault: true)];
      expect(chipLanguages(rows, oneModelForAll: false), isEmpty);
    });

    test('a downloading language keeps its chip while the ring runs', () {
      final rows = [row(installFraction: 0.4)];
      expect(chipLanguages(rows, oneModelForAll: false), rows);
    });

    test('a merely supported language stays in the sheet, not the strip', () {
      expect(chipLanguages([row()], oneModelForAll: false), isEmpty);
    });

    test('a ready language wearing a refused remove loses its chip', () {
      final rows = [
        row(
          status: ModelAssetStatus.installed,
          reserved: true,
          failure: const LanguageFailure(kind: LanguageFailureKind.removeFailed),
        ),
      ];
      expect(chipLanguages(rows, oneModelForAll: false), isEmpty);
    });

    test('an unsupported language never wears a chip', () {
      expect(
        chipLanguages([row(status: ModelAssetStatus.unsupported)], oneModelForAll: false),
        isEmpty,
      );
    });
  });

  group('languageStripShown', () {
    test('an engine with a model per language keeps the strip for its Add chip', () {
      expect(languageStripShown(oneModelForAll: false, heroBroken: false), isTrue);
    });

    test('under one model for every language the strip steps aside for the hero', () {
      expect(languageStripShown(oneModelForAll: true, heroBroken: false), isFalse);
    });

    test('a broken default keeps the strip as the library door its hero is not', () {
      expect(languageStripShown(oneModelForAll: true, heroBroken: true), isTrue);
    });
  });
}
