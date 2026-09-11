import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/services/transcription_service.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/batch_progress_label.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  BatchProgress progress(BatchStep step, double fraction, {String? modelName}) =>
      BatchProgress(entryId: null, step: step, fraction: fraction, modelName: modelName);

  test('no pass has no line', () {
    expect(batchProgressLabel(l10n, null), isNull);
    expect(batchProgressLabel(l10n, progress(BatchStep.done, 1)), isNull);
  });

  test('a run that has not reported yet names the work without a number', () {
    expect(batchProgressLabel(l10n, progress(BatchStep.transcribing, 0)), l10n.takeTranscribing);
  });

  test('a run rounding below half a percent still shows no number', () {
    expect(
      batchProgressLabel(l10n, progress(BatchStep.transcribing, 0.004)),
      l10n.takeTranscribing,
    );
  });

  test('a run that reported takes the percent', () {
    expect(
      batchProgressLabel(l10n, progress(BatchStep.transcribing, 0.5)),
      l10n.takeTranscribingProgress(50),
    );
  });

  test('a download shows its model and percent from the first byte', () {
    expect(
      batchProgressLabel(l10n, progress(BatchStep.downloading, 0, modelName: 'Base')),
      l10n.takeDownloadingProgress('Base', 0),
    );
  });
}
