import 'package:opentranscribe/core/services/transcription_service.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/formatting.dart';

/// One line for a batch pass in flight: the run's percent, or the model's
/// download ahead of it. Null once the pass is over.
String? batchProgressLabel(AppLocalizations l10n, BatchProgress? progress) {
  if (progress == null) return null;
  final percent = percentOf(progress.fraction);
  return switch (progress.step) {
    BatchStep.done => null,
    BatchStep.downloading => l10n.takeDownloadingProgress(progress.modelName ?? '', percent),
    BatchStep.transcribing => l10n.takeTranscribingProgress(percent),
  };
}
