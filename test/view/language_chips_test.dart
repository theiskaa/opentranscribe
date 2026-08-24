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
      expect(chipLanguages(rows), rows);
    });

    test('the default never wears a chip, the hero carries it', () {
      final rows = [row(status: ModelAssetStatus.installed, reserved: true, isDefault: true)];
      expect(chipLanguages(rows), isEmpty);
    });

    test('a downloading language keeps its chip while the ring runs', () {
      final rows = [row(installFraction: 0.4)];
      expect(chipLanguages(rows), rows);
    });

    test('a merely supported language stays in the sheet, not the strip', () {
      expect(chipLanguages([row()]), isEmpty);
    });

    test('a ready language wearing a refused remove loses its chip', () {
      final rows = [
        row(
          status: ModelAssetStatus.installed,
          reserved: true,
          failure: const LanguageFailure(kind: LanguageFailureKind.removeFailed),
        ),
      ];
      expect(chipLanguages(rows), isEmpty);
    });

    test('an unsupported language never wears a chip', () {
      expect(chipLanguages([row(status: ModelAssetStatus.unsupported)]), isEmpty);
    });
  });
}
