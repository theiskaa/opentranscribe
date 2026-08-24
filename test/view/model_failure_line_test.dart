import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:opentranscribe/core/state/settings_cubit.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/model_failure_line.dart';
import 'package:transcriber/transcriber.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  LanguageModelState row({
    ModelAssetStatus status = ModelAssetStatus.supported,
    LanguageFailure? failure,
    double? installFraction,
  }) => LanguageModelState(
    tag: 'en-US',
    status: status,
    reserved: false,
    isDefault: false,
    failure: failure,
    installFraction: installFraction,
  );

  group('modelTroubleLine', () {
    test('a standing failure outranks everything else on the row', () {
      final r = row(
        status: ModelAssetStatus.unsupported,
        failure: const LanguageFailure(kind: LanguageFailureKind.capReached),
      );
      expect(modelTroubleLine(l10n, r, managesModels: true), l10n.transcriptionErrorCap);
    });

    test('unready under a managed engine reads as unsupported', () {
      final r = row(status: ModelAssetStatus.unsupported);
      expect(modelTroubleLine(l10n, r, managesModels: true), l10n.transcriptionErrorUnsupported);
    });

    test('unready under dictation points at the system keyboard setting', () {
      final r = row(status: ModelAssetStatus.unsupported);
      expect(modelTroubleLine(l10n, r, managesModels: false), l10n.languageNeedsDictation);
    });

    test('a system download this cubit does not drive reads as stuck', () {
      final r = row(status: ModelAssetStatus.downloading);
      expect(modelTroubleLine(l10n, r, managesModels: true), l10n.transcriptionErrorStuck);
    });

    test('a download this cubit drives is not trouble', () {
      final r = row(status: ModelAssetStatus.downloading, installFraction: 0.5);
      expect(modelTroubleLine(l10n, r, managesModels: true), isNull);
    });

    test('a plain ready row has nothing to say', () {
      expect(
        modelTroubleLine(l10n, row(status: ModelAssetStatus.installed), managesModels: true),
        isNull,
      );
    });
  });
}
