import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/state/models_cubit.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
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

  group('modelRowRemovable', () {
    test('a present model offers its trash unless it is the one in use', () {
      expect(modelRowRemovable(row(installed: true)), isTrue);
      expect(modelRowRemovable(row(installed: true, selected: true)), isFalse);
    });

    test('a model that would not open offers its trash even as the one in use', () {
      expect(
        modelRowRemovable(
          row(installed: true, selected: true, failure: ModelInstallReason.loadFailed),
        ),
        isTrue,
      );
    });

    test('an absent model, a failed download, or one in flight offers no trash', () {
      expect(modelRowRemovable(row()), isFalse);
      expect(modelRowRemovable(row(failure: ModelInstallReason.offline)), isFalse);
      expect(modelRowRemovable(row(installed: true, failure: ModelInstallReason.noSpace)), isFalse);
      expect(modelRowRemovable(row(installed: true, installFraction: 0.4)), isFalse);
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

  group('modelControlWidth', () {
    const bandHeight = 32.0;
    final label = AppType.footnote.copyWith(fontWeight: FontWeight.w600);

    double width({
      double floor = 0,
      double ceiling = double.infinity,
      TextScaler textScaler = TextScaler.noScaling,
    }) => modelControlWidth(
      l10n,
      bandHeight: bandHeight,
      floor: floor,
      ceiling: ceiling,
      textScaler: textScaler,
    );

    double measure(String text, TextStyle style) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
      )..layout();
      addTearDown(painter.dispose);
      return painter.width;
    }

    test('a floor above every face holds, so every control keeps one width', () {
      expect(width(floor: 500, ceiling: 600), 500);
    });

    test('the width stops at the ceiling, leaving the name its room', () {
      expect(width(ceiling: 10), 10);
    });

    test('a ceiling under the floor yields the floor rather than failing', () {
      expect(width(floor: 116, ceiling: 50), 116);
    });

    test('larger text widens the control', () {
      expect(width(textScaler: const TextScaler.linear(2)), greaterThan(width()));
    });

    test('it covers the queued bar beside its open cancel seat', () {
      final queued =
          measure(l10n.modelQueued, AppType.digits(label)) +
          2 * AppSpacing.sm +
          bandHeight +
          AppSpacing.sm;
      expect(width(), greaterThanOrEqualTo(queued));
    });

    test('it covers the download pill with its glyph at the width the icon font draws it', () {
      final glyph = measure(
        String.fromCharCode(AppIcons.icloud.codePoint),
        TextStyle(
          inherit: false,
          fontFamily: AppIcons.icloud.fontFamily,
          fontSize: ModelControl.glyphSize,
        ),
      );
      final download =
          measure(l10n.modelDownload, label) + 2 * AppSpacing.md + glyph + AppSpacing.xs;
      expect(width(), greaterThanOrEqualTo(download));
    });
  });
}
