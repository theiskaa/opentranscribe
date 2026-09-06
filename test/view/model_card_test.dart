import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/state/settings_cubit.dart';
import 'package:opentranscribe/view/layouts/settings/components/model_card.dart';
import 'package:transcriber/transcriber.dart';

void main() {
  const option = ModelOption(
    id: 'small',
    displayName: 'Small',
    bytes: 100,
    quality: ModelQuality.better,
    peakMemoryBytes: 1000,
  );

  ModelRowState row({
    bool installed = false,
    bool selected = false,
    bool heavy = false,
    double? installFraction,
    ModelInstallReason? failure,
  }) => ModelRowState(
    option: option,
    installed: installed,
    selected: selected,
    heavy: heavy,
    installFraction: installFraction,
    failure: failure,
  );

  group('modelRowFace', () {
    test('a download in flight shows itself whatever else is true', () {
      expect(modelRowFace(row(installFraction: 0.3, heavy: true)), ModelRowFace.installing);
      expect(modelRowFace(row(installFraction: 0, installed: true)), ModelRowFace.installing);
    });

    test('a failed download asks for its retry', () {
      expect(modelRowFace(row(failure: ModelInstallReason.offline)), ModelRowFace.failed);
    });

    test('a model this phone cannot hold is dimmed only while absent', () {
      expect(modelRowFace(row(heavy: true)), ModelRowFace.heavy);
      expect(modelRowFace(row(heavy: true, installed: true)), ModelRowFace.installed);
    });

    test('an absent model offers its download', () {
      expect(modelRowFace(row()), ModelRowFace.download);
    });

    test('a present model is the choice or removable', () {
      expect(modelRowFace(row(installed: true, selected: true)), ModelRowFace.selected);
      expect(modelRowFace(row(installed: true)), ModelRowFace.installed);
    });
  });
}
