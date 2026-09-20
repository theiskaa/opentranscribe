import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/state/models_cubit.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/model_sheet.dart';
import 'package:transcriber/transcriber.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  const option = ModelOption(
    id: 'medium',
    displayName: 'Medium',
    bytes: 539212467,
    quality: ModelQuality.best,
    peakMemoryBytes: 1000,
  );

  ModelRowState row({
    bool installed = false,
    bool selected = false,
    bool heavy = false,
    double? installFraction,
    bool preparing = false,
    bool queued = false,
    bool cancellable = false,
    ModelInstallReason? failure,
  }) => ModelRowState(
    option: option,
    installed: installed,
    selected: selected,
    heavy: heavy,
    installFraction: installFraction,
    preparing: preparing,
    queued: queued,
    cancellable: cancellable,
    failure: failure,
  );

  group('modelIsYours', () {
    test('a model that is here is yours', () {
      expect(modelIsYours(row(installed: true)), isTrue);
    });

    test('a model still downloading stays in its place until it lands', () {
      expect(modelIsYours(row(installFraction: 0.2)), isFalse);
      expect(modelIsYours(row(installFraction: 1, preparing: true)), isFalse);
    });

    test('a model here fetching its Neural Engine file stays yours', () {
      expect(modelIsYours(row(installed: true, installFraction: 0.5)), isTrue);
    });

    test('a model not here and not downloading stays with all the others', () {
      expect(modelIsYours(row()), isFalse);
      expect(modelIsYours(row(failure: ModelInstallReason.offline)), isFalse);
    });
  });

  group('modelSheetMark', () {
    test('the model in use wears the check', () {
      expect(modelSheetMark(row(installed: true, selected: true)), ModelSheetMark.check);
    });

    test('a kept model that is not in use offers its trash', () {
      expect(modelSheetMark(row(installed: true)), ModelSheetMark.trash);
    });

    test('a download that can be stopped shows the ring with its stop', () {
      expect(modelSheetMark(row(installFraction: 0.4, cancellable: true)), ModelSheetMark.stop);
      expect(
        modelSheetMark(row(installFraction: 0, queued: true, cancellable: true)),
        ModelSheetMark.stop,
      );
    });

    test('the Neural Engine preparation is a wait with nothing to stop', () {
      expect(
        modelSheetMark(row(installFraction: 1, preparing: true, cancellable: true)),
        ModelSheetMark.spinner,
      );
    });

    test('a failed download offers its retry', () {
      expect(modelSheetMark(row(failure: ModelInstallReason.offline)), ModelSheetMark.retry);
    });

    test('a model that downloaded but will not open offers its trash as the way out', () {
      expect(
        modelSheetMark(row(installed: true, failure: ModelInstallReason.loadFailed)),
        ModelSheetMark.trash,
      );
    });

    test('a model not here offers its download, and one too large offers nothing', () {
      expect(modelSheetMark(row()), ModelSheetMark.download);
      expect(modelSheetMark(row(heavy: true)), ModelSheetMark.none);
    });
  });

  group('modelSheetLine', () {
    test('a running download says how far it is', () {
      expect(
        modelSheetLine(l10n, row(installFraction: 0.42), localeTag: 'en'),
        '${l10n.transcriptionDownloading} · 42%',
      );
    });

    test('a queued download and the preparation say so instead of a percent', () {
      expect(
        modelSheetLine(l10n, row(installFraction: 0, queued: true), localeTag: 'en'),
        l10n.modelQueued,
      );
      expect(
        modelSheetLine(l10n, row(installFraction: 1, preparing: true), localeTag: 'en'),
        l10n.modelPreparing,
      );
    });

    test('a model at rest reads its size and tier', () {
      expect(
        modelSheetLine(l10n, row(installed: true), localeTag: 'en'),
        l10n.modelSizeAndQuality('539.2 MB', l10n.modelQualityBest),
      );
    });
  });
}
