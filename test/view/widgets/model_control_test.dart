import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/state/models_cubit.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/model_control.dart';
import 'package:opentranscribe/view/widgets/morph_control.dart';
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
      final face = progressFace(
        l10n,
        queued: true,
        preparing: false,
        fraction: 0.4,
        localeTag: 'en',
      );

      expect(face.fill, 0);
      expect(face.label, l10n.modelQueued);
    });

    test('a download unpacking what it fetched reads as preparing at a full bar', () {
      final face = progressFace(
        l10n,
        queued: false,
        preparing: true,
        fraction: 0.4,
        localeTag: 'en',
      );

      expect(face.fill, 1);
      expect(face.label, l10n.modelPreparing);
    });

    test('a running download fills to the percent it shows, in the locale shape', () {
      final face = progressFace(
        l10n,
        queued: false,
        preparing: false,
        fraction: 0.426,
        localeTag: 'en',
      );

      expect(face.label, '43%');
      expect(face.fill, 0.43);
      final french = progressFace(
        l10n,
        queued: false,
        preparing: false,
        fraction: 0.426,
        localeTag: 'fr',
      );
      expect(french.label, '43\u00a0%');
    });

    test('a download a hair short of done never reads 100%', () {
      final face = progressFace(
        l10n,
        queued: false,
        preparing: false,
        fraction: 0.998,
        localeTag: 'en',
      );

      expect(face.label, '99%');
      expect(face.fill, 0.99);
    });

    test('a download with nothing reported yet is empty, not blank', () {
      final face = progressFace(
        l10n,
        queued: false,
        preparing: false,
        fraction: null,
        localeTag: 'en',
      );

      expect(face.fill, 0);
      expect(face.label, '0%');
    });
  });

  group('modelControlFace', () {
    test('a queued or preparing download stays the bar, reading its word', () {
      final queued =
          modelControlFace(l10n, row(installFraction: 0, queued: true), localeTag: 'en')
              as MorphBar;
      final preparing =
          modelControlFace(l10n, row(installFraction: 1, preparing: true), localeTag: 'en')
              as MorphBar;

      expect((queued.fill, queued.label), (0, l10n.modelQueued));
      expect((preparing.fill, preparing.label), (1, l10n.modelPreparing));
    });

    test('the download asks in the solid fill, in the caller\'s words when it has them', () {
      final plain = modelControlFace(l10n, row(), localeTag: 'en') as MorphButton;
      final sized =
          modelControlFace(l10n, row(), localeTag: 'en', downloadLabel: 'Download 40 MB')
              as MorphButton;

      expect(
        (plain.label, plain.icon, plain.variant),
        (l10n.modelDownload, AppIcons.icloud, MorphVariant.primary),
      );
      expect(sized.label, 'Download 40 MB');
    });

    test('a retry asks as loudly as the download it repeats', () {
      final face =
          modelControlFace(l10n, row(failure: ModelInstallReason.offline), localeTag: 'en')
              as MorphButton;

      expect(
        (face.label, face.icon, face.variant),
        (l10n.retry, AppIcons.arrowCounterclockwise, MorphVariant.primary),
      );
    });

    test('a download in flight shows its bar over a failure still standing', () {
      expect(
        modelControlFace(
          l10n,
          row(installFraction: 0.2, failure: ModelInstallReason.offline),
          localeTag: 'en',
        ),
        isA<MorphBar>(),
      );
    });
  });

  group('modelControlSemanticLabel', () {
    test('a running download names the model and the percent it shows', () {
      expect(
        modelControlSemanticLabel(l10n, row(installFraction: 0.426)),
        l10n.modelDownloadingLabel('Small', 43),
      );
    });

    test('a queued or preparing download says so rather than a percent', () {
      expect(
        modelControlSemanticLabel(l10n, row(installFraction: 0, queued: true)),
        l10n.modelQueuedLabel('Small'),
      );
      expect(
        modelControlSemanticLabel(l10n, row(installFraction: 1, preparing: true)),
        l10n.modelPreparingLabel('Small'),
      );
    });

    test(
      'the download reads as the caller\'s words when given, else as the model\'s download button',
      () {
        expect(modelControlSemanticLabel(l10n, row()), l10n.modelDownloadButton('Small'));
        expect(modelControlSemanticLabel(l10n, row(), downloadLabel: 'Get it'), 'Get it');
      },
    );

    test('a failed download reads as the retry for that model', () {
      expect(
        modelControlSemanticLabel(l10n, row(failure: ModelInstallReason.offline)),
        l10n.modelRetryButton('Small'),
      );
    });
  });

  group('modelControlCancellable', () {
    test('a download this surface started can be stopped until it is preparing', () {
      expect(modelControlCancellable(row(installFraction: 0.4, cancellable: true)), isTrue);
      expect(
        modelControlCancellable(row(installFraction: 1, cancellable: true, preparing: true)),
        isFalse,
      );
    });

    test('a download a batch started offers no cancel', () {
      expect(modelControlCancellable(row(installFraction: 0.4)), isFalse);
    });
  });
}
