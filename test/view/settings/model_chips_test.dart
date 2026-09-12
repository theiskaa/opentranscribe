import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/state/models_cubit.dart';
import 'package:opentranscribe/view/layouts/settings/components/model_chips.dart';
import 'package:transcriber/transcriber.dart';

void main() {
  ModelRowState row(
    String id, {
    bool installed = false,
    bool selected = false,
    double? installFraction,
    ModelInstallReason? failure,
  }) => ModelRowState(
    option: ModelOption(
      id: id,
      displayName: id,
      bytes: 100,
      quality: ModelQuality.good,
      peakMemoryBytes: 1000,
    ),
    installed: installed,
    selected: selected,
    heavy: false,
    installFraction: installFraction,
    failure: failure,
  );

  test('a downloaded model other than the one in use earns a chip', () {
    final base = row('base', installed: true);
    expect(chipModels([base, row('small', installed: true, selected: true)]), [base]);
  });

  test('the model in use never wears a chip, the card carries it', () {
    expect(chipModels([row('small', installed: true, selected: true)]), isEmpty);
  });

  test('a model on its way keeps a chip while its ring runs', () {
    final medium = row('medium', installFraction: 0.4);
    expect(chipModels([medium]), [medium]);
  });

  test('a model that is not here and not coming earns no chip', () {
    expect(chipModels([row('tiny')]), isEmpty);
  });

  test('a failed model stays out of the strip, its retry lives in the sheet', () {
    expect(
      chipModels([row('base', installed: true, failure: ModelInstallReason.loadFailed)]),
      isEmpty,
    );
    expect(chipModels([row('medium', failure: ModelInstallReason.offline)]), isEmpty);
  });

  test('chips keep the engine order', () {
    final rows = [
      row('tiny', installed: true),
      row('small', installed: true, selected: true),
      row('medium', installed: true),
    ];
    expect(chipModels(rows).map((r) => r.option.id), ['tiny', 'medium']);
  });

  group('chipsNeedDownloadNote', () {
    test('a chip downloading on its own asks for the note', () {
      final rows = [
        row('small', installed: true, selected: true),
        row('medium', installFraction: 0.4),
      ];
      expect(chipsNeedDownloadNote(rows, accelerated: false), isTrue);
    });

    test('the model in use has its own note under its bar, so the chips do not repeat it', () {
      final rows = [
        row('small', selected: true, installFraction: 0.2),
        row('medium', installFraction: 0),
      ];
      expect(chipsNeedDownloadNote(rows, accelerated: false), isFalse);
    });

    test('with no chip downloading there is nothing to say', () {
      final rows = [row('small', installed: true, selected: true), row('base', installed: true)];
      expect(chipsNeedDownloadNote(rows, accelerated: false), isFalse);
    });

    test('while the model in use is prepared, its bar says so, and the chips keep the note', () {
      final rows = [
        const ModelRowState(
          option: ModelOption(
            id: 'small',
            displayName: 'small',
            bytes: 100,
            quality: ModelQuality.good,
            peakMemoryBytes: 1000,
          ),
          installed: false,
          selected: true,
          heavy: false,
          installFraction: 1,
          preparing: true,
        ),
        row('medium', installFraction: 0.4),
      ];
      expect(chipsNeedDownloadNote(rows, accelerated: true), isTrue);
    });
  });
}
