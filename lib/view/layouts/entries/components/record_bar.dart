import 'package:flutter/cupertino.dart';

import 'package:opentranscribe/core/state/recorder_cubit.dart';
import 'package:opentranscribe/core/theming/app_theme.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/app_button.dart';

/// The bottom record control. Idle shows a big record button; recording shows the
/// elapsed time, any live text, and a stop button. Presentational: the screen
/// wires [onStart]/[onStop].
class RecordBar extends StatelessWidget {
  const RecordBar({required this.state, required this.onStart, required this.onStop, super.key});

  final RecorderState state;
  final VoidCallback onStart;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(top: BorderSide(color: colors.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: state.isRecording || state.status == RecorderStatus.saving
              ? _RecordingPanel(state: state, onStop: onStop)
              : _IdleControl(onStart: onStart),
        ),
      ),
    );
  }
}

class _IdleControl extends StatelessWidget {
  const _IdleControl({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: onStart,
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(color: colors.record, shape: BoxShape.circle),
            child: Icon(CupertinoIcons.mic_fill, color: colors.onAccent, size: 30),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(l10n.recordHint, style: AppText.caption(context)),
      ],
    );
  }
}

class _RecordingPanel extends StatelessWidget {
  const _RecordingPanel({required this.state, required this.onStop});

  final RecorderState state;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final saving = state.status == RecorderStatus.saving;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: colors.record, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(_formatElapsed(state.elapsed), style: AppText.heading(context)),
            const Spacer(),
            if (saving)
              const CupertinoActivityIndicator()
            else
              AppButton(label: l10n.recordStop, onPressed: onStop),
          ],
        ),
        if (state.liveText.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            state.liveText,
            style: AppText.body(context),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

String _formatElapsed(Duration d) {
  final minutes = d.inMinutes.toString().padLeft(2, '0');
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
