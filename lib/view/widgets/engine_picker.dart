import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/models/engine_descriptor.dart';
import 'package:opentranscribe/core/state/engines_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/app_sheet.dart';
import 'package:opentranscribe/view/widgets/melt_stack.dart';
import 'package:opentranscribe/view/widgets/segmented_control.dart';
import 'package:opentranscribe/view/widgets/sheet_message.dart';

/// The row the picker shows: the one a pick is waiting on, else the active
/// one. An all-unavailable registry still resolves an active engine, so the
/// first row stands in only while the rows trail the service by a frame.
EngineRowState shownRow(List<EngineRowState> rows, {String? pending}) {
  for (final row in rows) {
    if (row.descriptor.engineId == pending) return row;
  }
  for (final row in rows) {
    if (row.isActive) return row;
  }
  return rows.first;
}

/// The line under the control: what this engine is, or why it cannot run here.
String engineNote(AppLocalizations l10n, EngineRowState row) => row.available
    ? row.descriptor.blurb(l10n)
    // Exhaustive on purpose: a new unavailability kind must fail to compile
    // until it is worded, never silently borrow this one's words.
    : switch (row.unavailability!) {
        EngineUnavailability.needsNewerDevice => l10n.engineUnavailableNote,
        EngineUnavailability.storageUnavailable => l10n.engineStorageUnavailableNote,
      };

/// Why [row]'s engine cannot run here, in full, for an unavailable row.
String engineUnavailableBody(AppLocalizations l10n, EngineRowState row) =>
    switch (row.unavailability!) {
      EngineUnavailability.needsNewerDevice => l10n.engineUnavailableBody(
        row.descriptor.displayName,
      ),
      EngineUnavailability.storageUnavailable => l10n.engineStorageUnavailableBody(
        row.descriptor.displayName,
      ),
    };

/// The sheet a refused pick opens, or null for one that took. [busy] is a
/// take in flight; [retranscribing] the bulk run, so they word apart.
({IconData icon, String title, String body})? refusalMessage(
  AppLocalizations l10n,
  EnginePickOutcome outcome,
) => switch (outcome) {
  EnginePickOutcome.busy => (
    icon: AppIcons.micFill,
    title: l10n.engineBusyTitle,
    body: l10n.engineBusyBody,
  ),
  EnginePickOutcome.retranscribing => (
    icon: AppIcons.arrowCounterclockwise,
    title: l10n.engineRetranscribingTitle,
    body: l10n.engineRetranscribingBody,
  ),
  _ => null,
};

/// Asks for [engineId] and words what did not take: a refusal, or a switch
/// whose choice will not survive a relaunch. [onAnswer] runs once the cubit
/// has answered, before any of that is said.
Future<void> pickEngine(BuildContext context, String engineId, {VoidCallback? onAnswer}) async {
  final EnginePickOutcome outcome;
  try {
    outcome = await context.read<EnginesCubit>().pick(engineId);
  } catch (_) {
    onAnswer?.call();
    if (context.mounted) await _explainEngineNotSaved(context);
    return;
  }
  onAnswer?.call();
  if (context.mounted) await explainRefusal(context, outcome);
}

/// A pick that threw: the switch (or its revert) happened and only the
/// stored choice is lost. The control already says what is active; this says
/// it will not hold. Quiet when the screen is no longer on top.
Future<void> _explainEngineNotSaved(BuildContext context) async {
  if (!(ModalRoute.of(context)?.isCurrent ?? false)) return;
  final l10n = AppLocalizations.of(context)!;
  await showAppSheet<void>(
    context,
    builder: (context) => SheetMessage(
      icon: AppIcons.internaldrive,
      title: l10n.engineNotSavedTitle,
      body: l10n.engineNotSavedBody,
    ),
  );
}

/// The sheet a refused pick opens; nothing for an [outcome] that took, or
/// when the screen is no longer on top.
Future<void> explainRefusal(BuildContext context, EnginePickOutcome outcome) async {
  final refusal = refusalMessage(AppLocalizations.of(context)!, outcome);
  if (refusal == null || !(ModalRoute.of(context)?.isCurrent ?? false)) return;
  await showAppSheet<void>(
    context,
    builder: (context) =>
        SheetMessage(icon: refusal.icon, title: refusal.title, body: refusal.body),
  );
}

/// The engine picker: one segmented control over the engines this build
/// ships, and under it what the chosen one is. Every engine keeps its
/// segment, an engine that cannot run here included, and a pick the app
/// refuses says why and returns the control to the engine in use.
class EnginePicker extends StatefulWidget {
  const EnginePicker({required this.rows, super.key});

  final List<EngineRowState> rows;

  @override
  State<EnginePicker> createState() => _EnginePickerState();
}

class _EnginePickerState extends State<EnginePicker> {
  /// The engine a tap moved to, until the app answers it. The control follows
  /// the finger through the ask, so a rebuild mid-pick cannot drag it back,
  /// and the answer is the only thing that moves it again.
  String? _pending;

  Future<void> _pick(String engineId) async {
    // One ask at a time: a second tap would land on a cubit that drops it and
    // leave the control arguing with the pick already running.
    if (_pending != null) return;
    final rows = widget.rows;
    final row = shownRow(rows, pending: engineId);
    if (row.descriptor.engineId != engineId) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() => _pending = engineId);
    try {
      if (!isTopRoute(context)) return;
      if (!row.available) {
        await showAppSheet<void>(
          context,
          builder: (context) => SheetMessage(
            icon: row.descriptor.logo,
            title: l10n.engineUnavailableTitle,
            body: engineUnavailableBody(l10n, row),
          ),
        );
        return;
      }
      await pickEngine(context, engineId);
    } finally {
      if (mounted) setState(() => _pending = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    final rows = widget.rows;
    if (rows.isEmpty) return const SizedBox.shrink();
    final shown = shownRow(rows, pending: _pending);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSegmentedControl<String>(
          segments: [for (final row in rows) (row.descriptor.engineId, row.descriptor.segmentName)],
          selected: shown.descriptor.engineId,
          onChanged: (engineId) => unawaited(_pick(engineId)),
        ),
        const SizedBox(height: AppSpacing.md),
        // The enclosing melt owns the height; this only crossfades the words,
        // keyed by them so an engine whose own line changed swaps too.
        AnimatedSwitcher(
          duration: context.reduceMotion ? Duration.zero : theme.motion.crossfade,
          layoutBuilder: meltStack,
          child: EngineNote(
            key: ValueKey((shown.descriptor.engineId, engineNote(l10n, shown))),
            row: shown,
          ),
        ),
      ],
    );
  }
}

/// The line under an engine's control: [engineNote], inset like a footnote.
class EngineNote extends StatelessWidget {
  const EngineNote({required this.row, super.key});

  final EngineRowState row;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Text(
        engineNote(AppLocalizations.of(context)!, row),
        style: AppType.note.copyWith(color: context.theme.textSecondary),
      ),
    );
  }
}
