import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/services/retranscribe_runner.dart';
import 'package:opentranscribe/core/state/engines_cubit.dart';
import 'package:opentranscribe/core/state/entries_cubit.dart';
import 'package:opentranscribe/core/state/retranscribe_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/app_icons.dart';
import 'package:opentranscribe/core/theming/app_motion.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/core/utils/haptics.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/app_button.dart';
import 'package:opentranscribe/view/widgets/app_sheet.dart';
import 'package:opentranscribe/view/widgets/entrance_rise.dart';
import 'package:opentranscribe/view/widgets/formatting.dart';
import 'package:opentranscribe/view/widgets/progress_ring.dart';
import 'package:opentranscribe/view/widgets/rolling_text.dart';
import 'package:opentranscribe/view/widgets/sheet_message.dart';
import 'package:opentranscribe/view/widgets/support_gate_sheet.dart';

/// The bulk re-transcription sheet, off the transcription screen's row under
/// the engine picker. Club-gated whole, like the entry export sheet: for a
/// non-supporter the gate takes its place. The run belongs to the root-scoped
/// cubit, so dismissing the sheet stops nothing; reopening lands on the live
/// face.
Future<void> showRetranscribeSheet(BuildContext context) async {
  // TEMP: club gate bypassed for the device pass; restore this line and the
  // core/app/deps.dart import before commit.
  // if (!Deps.i.supportService.tier.isSupporter) return showSupportGateSheet(context);
  context.read<RetranscribeCubit>().refresh();
  final locked = await showAppSheet<bool>(
    context,
    builder: (context) => const _RetranscribeSheetBody(),
  );
  // The entitlement lapsed while the sheet was open; the gate answers the
  // refusal here, over the surface that owns the context.
  if (locked == true && context.mounted) return showSupportGateSheet(context);
}

enum RetranscribeFace { idle, running, finished }

/// Which face the sheet shows for [phase]. A terminal phase reads as the
/// summary only when [sawRunning] (this opening watched the run); otherwise
/// it is old news and the fresh preview takes its place.
RetranscribeFace retranscribeFace(RetranscribePhase phase, {required bool sawRunning}) =>
    switch (phase) {
      RetranscribePhase.running => RetranscribeFace.running,
      RetranscribePhase.done ||
      RetranscribePhase.cancelled when sawRunning => RetranscribeFace.finished,
      _ => RetranscribeFace.idle,
    };

/// The display name of the engine a run would use: the picker's active row.
/// The registry always marks one, so an empty answer only ever means a
/// surface built before the cubit derived its rows.
String activeEngineName(List<EngineRowState> rows) =>
    rows.where((row) => row.isActive).firstOrNull?.descriptor.displayName ?? '';

/// The ring's fraction: settled work over the queue, clamped, and 0 for an
/// empty queue so a run cancelled at zero never divides by zero.
double retranscribeFraction(RetranscribeProgress progress) =>
    progress.total == 0 ? 0 : (progress.done / progress.total).clamp(0.0, 1.0);

class _RetranscribeSheetBody extends StatefulWidget {
  const _RetranscribeSheetBody();

  @override
  State<_RetranscribeSheetBody> createState() => _RetranscribeSheetBodyState();
}

class _RetranscribeSheetBodyState extends State<_RetranscribeSheetBody> {
  /// Whether THIS opening of the sheet watched the run happen. A terminal
  /// phase only reads as a summary to the opening that saw it running; a
  /// sheet opened days later opens on the fresh preview instead of a stale
  /// report. Seeded from the live state so an opening mid-run reads the
  /// summary even when the run lands without emitting again.
  late bool _sawRunning = context.read<RetranscribeCubit>().state.isRunning;

  @override
  Widget build(BuildContext context) {
    final motion = context.theme.motion;
    final reduce = context.reduceMotion;
    final state = context.watch<RetranscribeCubit>().state;
    final progress = state.progress;
    final faceKey = retranscribeFace(progress.phase, sawRunning: _sawRunning);
    final Widget face = switch (faceKey) {
      RetranscribeFace.running => _RunningFace(progress: progress),
      RetranscribeFace.finished => _FinishedFace(progress: progress),
      RetranscribeFace.idle => _IdleFace(state: state),
    };
    return MultiBlocListener(
      listeners: [
        // Latched from a listener, not from build: provider coalesces
        // notifications, so a run that reaches terminal within one frame
        // (an all-skipped queue, instant failures) never shows build a
        // running state - and without the latch its summary would be lost.
        BlocListener<RetranscribeCubit, RetranscribeState>(
          listenWhen: (_, next) => next.isRunning,
          listener: (_, _) {
            if (!_sawRunning) setState(() => _sawRunning = true);
          },
        ),
        // Done only: a cancel is the user's own hand, already ticked by the
        // button press, and a second pulse would read as a double commit.
        BlocListener<RetranscribeCubit, RetranscribeState>(
          listenWhen: (previous, next) =>
              previous.progress.phase == RetranscribePhase.running &&
              next.progress.phase == RetranscribePhase.done,
          listener: (_, _) => Haptics.medium(),
        ),
      ],
      child: AnimatedSize(
        duration: reduce ? AppMotion.instant : motion.expand,
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: AnimatedSwitcher(
          duration: reduce ? Duration.zero : motion.crossfade,
          child: KeyedSubtree(key: ValueKey(faceKey), child: face),
        ),
      ),
    );
  }
}

class _IdleFace extends StatelessWidget {
  const _IdleFace({required this.state});

  final RetranscribeState state;

  void _start(BuildContext context) {
    final started = context.read<RetranscribeCubit>().start();
    // The entitlement lapsed under an open sheet; hand the refusal back so
    // the gate opens where this sheet stood.
    if (started == RetranscribeStart.locked) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final hasWork = state.runnable > 0;
    final engine = activeEngineName(context.watch<EnginesCubit>().state.rows);
    return SheetMessage(
      icon: AppIcons.arrowCounterclockwise,
      title: l10n.retranscribeAllTitle,
      body: hasWork
          ? l10n.retranscribeIdleBody(state.runnable, state.current, engine)
          : l10n.retranscribeAllCurrentBody(engine),
      action: hasWork
          ? AppButton(label: l10n.retranscribeStart, onPressed: () => _start(context))
          : null,
    );
  }
}

class _RunningFace extends StatelessWidget {
  const _RunningFace({required this.progress});

  final RetranscribeProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    final fraction = retranscribeFraction(progress);
    return SheetMessage(
      icon: AppIcons.arrowCounterclockwise,
      title: l10n.retranscribeAllTitle,
      rows: [
        Center(child: ProgressRing(fraction: fraction, size: 96, strokeWidth: 4)),
        const SizedBox(height: AppSpacing.xl),
        // The whole localized line rides one odometer, so locales that order
        // total-first keep their order; unchanged slots hold still.
        Center(
          child: RollingText(
            text: l10n.retranscribeProgressOf(progress.done, progress.total),
            style: AppType.digits(AppType.display2).copyWith(color: theme.text),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Center(child: _CurrentLine(progress: progress)),
      ],
      action: AppButton(
        label: l10n.retranscribeCancel,
        variant: AppButtonVariant.secondary,
        onPressed: () => context.read<RetranscribeCubit>().cancel(),
      ),
    );
  }
}

/// The one line under the counter: what the run is doing right now. The
/// waiting hold outranks the entry name; an empty settle between entries
/// keeps the line's height so the sheet never jitters.
class _CurrentLine extends StatelessWidget {
  const _CurrentLine({required this.progress});

  final RetranscribeProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    var label = switch (progress.hold) {
      RetranscribeHold.capture => l10n.retranscribeWaitingRecording,
      RetranscribeHold.thermal => l10n.retranscribeWaitingThermal,
      RetranscribeHold.none => ' ',
    };
    if (progress.hold == RetranscribeHold.none && progress.currentEntryId != null) {
      final entries = context.watch<EntriesCubit>().state.entries;
      for (final entry in entries) {
        if (entry.id == progress.currentEntryId) {
          label = entryDisplayTitle(entry, localeTag(context));
          break;
        }
      }
    }
    return AnimatedSwitcher(
      duration: context.reduceMotion ? Duration.zero : context.theme.motion.crossfade,
      child: Text(
        label,
        key: ValueKey(label),
        style: AppType.footnote.copyWith(color: theme.textSecondary),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _FinishedFace extends StatelessWidget {
  const _FinishedFace({required this.progress});

  final RetranscribeProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    final cancelled = progress.phase == RetranscribePhase.cancelled;
    final body = cancelled
        ? l10n.retranscribeCancelledBody(progress.landed)
        : progress.failed > 0
        ? l10n.retranscribeDoneFailedBody(progress.landed, progress.failed)
        : l10n.retranscribeDoneBody(progress.landed);
    return SheetMessage(
      icon: AppIcons.arrowCounterclockwise,
      title: l10n.retranscribeAllTitle,
      // As a row, not the body slot: only the summary earns the rise, while
      // the header stays the constant the crossfade already carries.
      rows: [
        EntranceRise(
          child: Text(
            body,
            style: AppType.subhead.copyWith(color: theme.textSecondary, height: 1.5),
          ),
        ),
      ],
      action: AppButton(label: l10n.done, onPressed: () => Navigator.of(context).pop()),
    );
  }
}
