import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/app/deps.dart';
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
import 'package:opentranscribe/view/widgets/formatting.dart';
import 'package:opentranscribe/view/widgets/progress_ring.dart';
import 'package:opentranscribe/view/widgets/rolling_text.dart';
import 'package:opentranscribe/view/widgets/sheet_message.dart';
import 'package:opentranscribe/view/widgets/support_gate_sheet.dart';

/// Club-gated whole, like the entry export sheet. The run belongs to the
/// root-scoped cubit, so dismissing stops nothing; reopening lands on the live face.
Future<void> showRetranscribeSheet(BuildContext context) async {
  if (!Deps.i.supportService.tier.isSupporter) return showSupportGateSheet(context);
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

/// The active row's display name; empty only on a surface built before the
/// cubit derived its rows.
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
    // Same subtitle on every face, so the header never re-seats on a swap.
    final engine = activeEngineName(context.watch<EnginesCubit>().state.rows);
    final faceKey = retranscribeFace(progress.phase, sawRunning: _sawRunning);
    final Widget face = switch (faceKey) {
      RetranscribeFace.running => _RunningFace(progress: progress, engine: engine),
      RetranscribeFace.finished => _FinishedFace(progress: progress, engine: engine),
      RetranscribeFace.idle => _IdleFace(state: state, engine: engine),
    };
    return MultiBlocListener(
      listeners: [
        // Latched in a listener: a run that lands within one frame never shows
        // build a running state, and its summary would be lost.
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
      // A crossfade or rise on the incoming face reads as the sheet closing and reopening.
      child: AnimatedSize(
        duration: reduce ? AppMotion.instant : motion.expand,
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: face,
      ),
    );
  }
}

class _IdleFace extends StatelessWidget {
  const _IdleFace({required this.state, required this.engine});

  final RetranscribeState state;
  final String engine;

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
    return SheetMessage(
      icon: AppIcons.arrowCounterclockwise,
      title: l10n.retranscribeAllTitle,
      subtitle: engine,
      body: hasWork ? null : l10n.retranscribeAllCurrentBody(engine),
      rows: [
        if (hasWork)
          _Facts(
            rows: [
              (l10n.retranscribeRowQueued, state.runnable),
              (l10n.retranscribeRowCurrent, state.current),
            ],
            note: l10n.retranscribeHistoryNote,
          ),
      ],
      action: hasWork
          ? AppButton(label: l10n.retranscribeStart, onPressed: () => _start(context))
          : null,
    );
  }
}

/// Rows, not prose, so a count never has to agree with a sentence in any locale.
class _Facts extends StatelessWidget {
  const _Facts({required this.rows, this.note});

  final List<(String, int)> rows;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, (label, count)) in rows.indexed) ...[
          if (i > 0) Container(height: 1, color: theme.settings.dividerColor),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: Text(label, style: AppType.subhead.copyWith(color: theme.textSecondary)),
                ),
                Text('$count', style: AppType.digits(AppType.subhead).copyWith(color: theme.text)),
              ],
            ),
          ),
        ],
        if (note != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(note!, style: AppType.footnote.copyWith(color: theme.textSecondary, height: 1.5)),
        ],
      ],
    );
  }
}

class _RunningFace extends StatelessWidget {
  const _RunningFace({required this.progress, required this.engine});

  final RetranscribeProgress progress;
  final String engine;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    final fraction = retranscribeFraction(progress);
    return SheetMessage(
      icon: AppIcons.arrowCounterclockwise,
      title: l10n.retranscribeAllTitle,
      subtitle: engine,
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
  const _FinishedFace({required this.progress, required this.engine});

  final RetranscribeProgress progress;
  final String engine;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final note = switch (progress.phase) {
      RetranscribePhase.cancelled => l10n.retranscribeCancelledNote,
      _ when progress.failed > 0 => l10n.retranscribeFailedNote,
      _ => null,
    };
    return SheetMessage(
      icon: AppIcons.arrowCounterclockwise,
      title: l10n.retranscribeAllTitle,
      subtitle: engine,
      rows: [
        _Facts(
          rows: [
            (l10n.retranscribeRowLanded, progress.landed),
            if (progress.failed > 0) (l10n.retranscribeRowFailed, progress.failed),
          ],
          note: note,
        ),
      ],
      action: AppButton(label: l10n.done, onPressed: () => Navigator.of(context).pop()),
    );
  }
}
