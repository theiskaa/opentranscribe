import 'package:opentranscribe/core/services/transcription_service.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/formatting.dart';

/// One line for a batch pass in flight: the run's percent, or the model's
/// download ahead of it. Null once the pass is over.
///
/// A run reports at the pace of whisper's own windows, 30 seconds of audio
/// each, so a short entry has nothing to report until it is done: the line
/// names the work and takes the number only once there is one.
String? batchProgressLabel(AppLocalizations l10n, BatchProgress? progress) {
  if (progress == null) return null;
  final percent = percentOf(progress.fraction);
  return switch (progress.step) {
    BatchStep.done => null,
    BatchStep.downloading => l10n.takeDownloadingProgress(progress.modelName ?? '', percent),
    BatchStep.transcribing when percent == 0 => l10n.takeTranscribing,
    BatchStep.transcribing => l10n.takeTranscribingProgress(percent),
  };
}
