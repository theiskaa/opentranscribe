import 'package:flutter_test/flutter_test.dart';

import 'package:opentranscribe/core/state/settings_cubit.dart';
import 'package:opentranscribe/view/widgets/language_sheet.dart';
import 'package:transcriber/transcriber.dart';

void main() {
  LanguageModelState row({
    ModelAssetStatus status = ModelAssetStatus.supported,
    bool reserved = false,
    bool isDefault = false,
  }) => LanguageModelState(tag: 'en-US', status: status, reserved: reserved, isDefault: isDefault);

  group('keptLanguage', () {
    test('the default is yours even when it cannot transcribe yet', () {
      final r = row(status: ModelAssetStatus.unsupported, isDefault: true);
      expect(keptLanguage(r, managesModels: true, oneModelForAll: false), isTrue);
      expect(keptLanguage(r, managesModels: false, oneModelForAll: false), isTrue);
      expect(keptLanguage(r, managesModels: true, oneModelForAll: true), isTrue);
    });

    test('under a managed engine a held slot is yours, ready or broken', () {
      final r = row(status: ModelAssetStatus.downloading, reserved: true);
      expect(keptLanguage(r, managesModels: true, oneModelForAll: false), isTrue);
    });

    test('under dictation only what transcribes now is yours', () {
      final unready = row(reserved: true);
      final ready = row(status: ModelAssetStatus.installed, reserved: true);
      expect(keptLanguage(unready, managesModels: false, oneModelForAll: false), isFalse);
      expect(keptLanguage(ready, managesModels: false, oneModelForAll: false), isTrue);
    });

    test('an unheld supported language is the library, not yours', () {
      expect(keptLanguage(row(), managesModels: true, oneModelForAll: false), isFalse);
    });

    test('under one model for every language only the default is yours', () {
      final ready = row(status: ModelAssetStatus.installed, reserved: true);
      expect(keptLanguage(ready, managesModels: true, oneModelForAll: true), isFalse);
    });
  });

  group('sheetRowInstalls', () {
    test('a managed engine with a cap offers an unready supported language', () {
      expect(
        sheetRowInstalls(row(), managesModels: true, reservationMax: 3, oneModelForAll: false),
        isTrue,
      );
    });

    test('no cap and no model choice offers nothing', () {
      expect(
        sheetRowInstalls(row(), managesModels: true, reservationMax: 0, oneModelForAll: false),
        isFalse,
      );
      expect(
        sheetRowInstalls(row(), managesModels: false, reservationMax: 0, oneModelForAll: false),
        isFalse,
      );
    });

    test('under one model for every language only the default row installs', () {
      expect(
        sheetRowInstalls(
          row(isDefault: true),
          managesModels: true,
          reservationMax: 0,
          oneModelForAll: true,
        ),
        isTrue,
      );
      expect(
        sheetRowInstalls(row(), managesModels: true, reservationMax: 0, oneModelForAll: true),
        isFalse,
      );
    });

    test('a ready or unsupported language never installs', () {
      final ready = row(status: ModelAssetStatus.installed, reserved: true, isDefault: true);
      final unsupported = row(status: ModelAssetStatus.unsupported, isDefault: true);
      expect(
        sheetRowInstalls(ready, managesModels: true, reservationMax: 3, oneModelForAll: true),
        isFalse,
      );
      expect(
        sheetRowInstalls(unsupported, managesModels: true, reservationMax: 3, oneModelForAll: true),
        isFalse,
      );
    });
  });

  group('sheetRowPicks', () {
    test('a ready language picks', () {
      final ready = row(status: ModelAssetStatus.installed, reserved: true);
      expect(sheetRowPicks(ready, oneModelForAll: false), isTrue);
      expect(sheetRowPicks(row(), oneModelForAll: false), isFalse);
    });

    test('under one model for every language any supported non-default picks', () {
      expect(sheetRowPicks(row(), oneModelForAll: true), isTrue);
      expect(sheetRowPicks(row(isDefault: true), oneModelForAll: true), isFalse);
      expect(
        sheetRowPicks(row(status: ModelAssetStatus.unsupported), oneModelForAll: true),
        isFalse,
      );
    });
  });
}
