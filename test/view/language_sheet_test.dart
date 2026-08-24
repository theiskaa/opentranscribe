import 'package:flutter_test/flutter_test.dart';

import 'package:opentranscribe/core/state/settings_cubit.dart';
import 'package:opentranscribe/view/layouts/settings/components/language_sheet.dart';
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
      expect(keptLanguage(r, managesModels: true), isTrue);
      expect(keptLanguage(r, managesModels: false), isTrue);
    });

    test('under a managed engine a held slot is yours, ready or broken', () {
      final r = row(status: ModelAssetStatus.downloading, reserved: true);
      expect(keptLanguage(r, managesModels: true), isTrue);
    });

    test('under dictation only what transcribes now is yours', () {
      final unready = row(reserved: true);
      final ready = row(status: ModelAssetStatus.installed, reserved: true);
      expect(keptLanguage(unready, managesModels: false), isFalse);
      expect(keptLanguage(ready, managesModels: false), isTrue);
    });

    test('an unheld supported language is the library, not yours', () {
      expect(keptLanguage(row(), managesModels: true), isFalse);
    });
  });
}
