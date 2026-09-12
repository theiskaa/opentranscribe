import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/state/models_cubit.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/model_card.dart';
import 'package:transcriber/transcriber.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  ModelRowState row(ModelInstallReason failure) => ModelRowState(
    option: const ModelOption(
      id: 'small',
      displayName: 'Small',
      bytes: 100,
      quality: ModelQuality.better,
      peakMemoryBytes: 1000,
    ),
    installed: true,
    selected: true,
    heavy: false,
    failure: failure,
  );

  test('a model that would not open says so instead of blaming the download', () {
    final (title, body) = modelFailureWords(
      l10n,
      row(ModelInstallReason.loadFailed),
      localeTag: 'en',
    );

    expect(title, l10n.modelFailLoadTitle);
    expect(body, l10n.modelFailLoadBody('Small'));
    expect(title, isNot(l10n.modelFailRejectedTitle));
  });

  test('a download that did not verify keeps its own words', () {
    final (title, _) = modelFailureWords(l10n, row(ModelInstallReason.rejected), localeTag: 'en');

    expect(title, l10n.modelFailRejectedTitle);
  });
}
