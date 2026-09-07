import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/state/settings_cubit.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/layouts/settings/components/model_control.dart';
import 'package:transcriber/transcriber.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

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

  group('progressFace', () {
    test('a download waiting its turn reads as the queue at an empty bar', () {
      final face = progressFace(l10n, queued: true, preparing: false, fraction: 0.4);

      expect(face.fill, 0);
      expect(face.label, l10n.modelQueued);
    });

    test('a download unpacking what it fetched reads as preparing at a full bar', () {
      final face = progressFace(l10n, queued: false, preparing: true, fraction: 0.4);

      expect(face.fill, 1);
      expect(face.label, l10n.modelPreparing);
    });

    test('a running download fills to the percent it shows', () {
      final face = progressFace(l10n, queued: false, preparing: false, fraction: 0.426);

      expect(face.label, '43%');
      expect(face.fill, 0.43);
    });

    test('a download with nothing reported yet is empty, not blank', () {
      final face = progressFace(l10n, queued: false, preparing: false, fraction: null);

      expect(face.fill, 0);
      expect(face.label, '0%');
    });
  });
}
