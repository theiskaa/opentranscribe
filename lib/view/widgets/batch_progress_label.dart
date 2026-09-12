import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/services/transcription_service.dart';
import 'package:opentranscribe/core/state/batch_progress_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/formatting.dart';
import 'package:opentranscribe/view/widgets/rolling_text.dart';

/// One line for a batch pass in flight: the run's percent, or the model's
/// download ahead of it. Null once the pass is over.
///
/// An engine may report nothing until a short run is done, so the line names
/// the work and takes the number only once there is one.
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

/// A bar's quiet line for the pass [select] picks: its [batchProgressLabel],
/// else [fallback], else nothing. Every changed character moves together,
/// fast, so a ticking percent reads as one number.
class BatchProgressLine extends StatelessWidget {
  const BatchProgressLine({required this.select, this.fallback, this.direction = 1, super.key});

  final BatchProgress? Function(BatchProgressState passes) select;
  final String? fallback;

  /// Which way changed characters roll; see [RollingText.direction].
  final int direction;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return BlocSelector<BatchProgressCubit, BatchProgressState, BatchProgress?>(
      selector: select,
      builder: (context, progress) {
        final text = batchProgressLabel(AppLocalizations.of(context)!, progress) ?? fallback;
        if (text == null) return const SizedBox.shrink();
        return RollingText(
          text: text,
          style: AppType.footnote.copyWith(color: theme.textSecondary),
          direction: direction,
          window: theme.motion.subtitleRoll,
          stagger: Duration.zero,
        );
      },
    );
  }
}
