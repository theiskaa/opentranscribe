import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/state/models_cubit.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/layouts/settings/components/model_card.dart';
import 'package:transcriber/transcriber.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  ModelRowState row({
    String id = 'small',
    int accelerationBytes = 163000000,
    bool installed = false,
    bool selected = false,
    bool heavy = false,
    bool accelerated = false,
    bool preparing = false,
    double? installFraction,
    ModelInstallReason? failure,
  }) => ModelRowState(
    option: ModelOption(
      id: id,
      displayName: 'Small',
      bytes: 190000000,
      quality: ModelQuality.better,
      peakMemoryBytes: 1000,
      accelerationBytes: accelerationBytes,
    ),
    installed: installed,
    selected: selected,
    heavy: heavy,
    accelerated: accelerated,
    preparing: preparing,
    installFraction: installFraction,
    failure: failure,
  );

  group('modelLine', () {
    String line(ModelRowState row) => modelLine(l10n, row, localeTag: 'en');

    test('a model on the phone reads its size and tier', () {
      expect(line(row(installed: true, selected: true)), '190.0 MB · Better');
    });

    test('the size is the model alone, whatever the Neural Engine adds', () {
      expect(line(row(installed: true, accelerated: true)), '190.0 MB · Better');
    });

    test('a model not on the phone says so with the size it will take', () {
      expect(line(row()), 'Not downloaded · 190.0 MB');
    });

    test('a model on its way reads its size and tier while the bar says the rest', () {
      expect(line(row(installFraction: 0.4)), '190.0 MB · Better');
    });

    test('a failed download names what went wrong', () {
      expect(line(row(failure: ModelInstallReason.offline)), l10n.modelFailOfflineTitle);
    });

    test('a model this phone cannot hold says so while absent', () {
      expect(line(row(heavy: true)), l10n.modelTooHeavyNote);
    });
  });

  group('modelWaitNote', () {
    test('a download says it needs the app open', () {
      expect(
        modelWaitNote(l10n, row(installFraction: 0.4), accelerated: true),
        l10n.transcriptionDownloadFootnote,
      );
    });

    test('the preparing tail under the Neural Engine says it takes minutes, once', () {
      expect(
        modelWaitNote(l10n, row(installFraction: 1, preparing: true), accelerated: true),
        l10n.modelPreparingNote,
      );
    });

    test('a preparing tail without the Neural Engine makes no promise of minutes', () {
      expect(
        modelWaitNote(l10n, row(installFraction: 1, preparing: true), accelerated: false),
        l10n.transcriptionDownloadFootnote,
      );
    });
  });

  group('accelerationFootprint', () {
    test('off, it adds a second file for every model on the phone', () {
      final rows = [
        row(id: 'base', accelerationBytes: 38, installed: true),
        row(accelerationBytes: 163, installed: true, selected: true),
        row(id: 'medium', accelerationBytes: 568),
      ];
      expect(accelerationFootprint(rows, on: false), (bytes: 201, uses: false));
    });

    test('a model on its way counts, its file comes along once it lands', () {
      final rows = [
        row(accelerationBytes: 163, installed: true, selected: true),
        row(id: 'medium', accelerationBytes: 568, installFraction: 0.3),
      ];
      expect(accelerationFootprint(rows, on: false), (bytes: 731, uses: false));
    });

    test('off with no model on the phone yet it adds the one in use', () {
      final rows = [
        row(id: 'base', accelerationBytes: 38),
        row(accelerationBytes: 163, selected: true),
      ];
      expect(accelerationFootprint(rows, on: false), (bytes: 163, uses: false));
    });

    test('just turned on, with the files still coming, it says what they add, never zero', () {
      final rows = [
        row(id: 'base', accelerationBytes: 38, installed: true, installFraction: 0.1),
        row(accelerationBytes: 163, installed: true, selected: true, installFraction: 0),
      ];
      expect(accelerationFootprint(rows, on: true), (bytes: 201, uses: false));
    });

    test('on with one file landed and one to go, it says what is still to add', () {
      final rows = [
        row(id: 'base', accelerationBytes: 38, installed: true, accelerated: true),
        row(accelerationBytes: 163, installed: true, selected: true, installFraction: 0.5),
      ];
      expect(accelerationFootprint(rows, on: true), (bytes: 163, uses: false));
    });

    test('on with every file on the phone, it says what they use', () {
      final rows = [
        row(id: 'base', accelerationBytes: 38, installed: true, accelerated: true),
        row(accelerationBytes: 163, installed: true, selected: true, accelerated: true),
        row(id: 'medium', accelerationBytes: 568),
      ];
      expect(accelerationFootprint(rows, on: true), (bytes: 201, uses: true));
    });

    test('on with no model on the phone yet it adds the one in use', () {
      final rows = [row(accelerationBytes: 163, selected: true)];
      expect(accelerationFootprint(rows, on: true), (bytes: 163, uses: false));
    });

    test('just turned off, before the reload clears the marks, it still counts every file', () {
      final rows = [
        row(id: 'base', accelerationBytes: 38, installed: true, accelerated: true),
        row(accelerationBytes: 163, installed: true, selected: true, accelerated: true),
      ];
      expect(accelerationFootprint(rows, on: false), (bytes: 201, uses: false));
    });

    test('with no model at all it says nothing costs anything', () {
      expect(accelerationFootprint(const [], on: true), (bytes: 0, uses: false));
    });
  });

  group('modelWaitIsPreparing', () {
    test('only the preparing tail under the Neural Engine is the long wait', () {
      expect(modelWaitIsPreparing(row(preparing: true), accelerated: true), isTrue);
      expect(modelWaitIsPreparing(row(preparing: true), accelerated: false), isFalse);
      expect(modelWaitIsPreparing(row(installFraction: 0.5), accelerated: true), isFalse);
    });
  });
}
