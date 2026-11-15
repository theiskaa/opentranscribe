import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/export/archive_codec.dart';
import 'package:opentranscribe/core/services/export_service.dart';
import 'package:opentranscribe/core/services/import_merge.dart';
import 'package:opentranscribe/core/services/import_service.dart';
import 'package:opentranscribe/core/state/backup_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/layouts/settings/components/backup_rules.dart';
import 'package:opentranscribe/view/widgets/animated_reveal.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/export_l10n.dart';
import 'package:opentranscribe/view/widgets/formatting.dart';
import 'package:opentranscribe/view/widgets/melt_stack.dart';
import 'package:opentranscribe/view/widgets/morph_control.dart';
import 'package:opentranscribe/view/widgets/passphrase_fields.dart';
import 'package:opentranscribe/view/widgets/settings_kit.dart';

/// Joins the parts of a quiet line, here and never inside a translation.
const _dot = ' · ';

/// The top card's name: the entry count, or an ellipsis until the first
/// measure lands, since zero would read as an empty journal.
String backupTitle(AppLocalizations l10n, JournalMeasure? measure) =>
    measure == null ? '…' : l10n.backupEntryCount(measure.entries);

/// The top card's facts: recordings, size, the last backup and what came
/// after it. A part that is unknown or zero is left out, so the line never
/// counts nothing or dates a backup that never happened; with no backup it
/// says so, and one made today says that instead of a date. Tests pin [now];
/// callers omit it.
String backupFacts(
  AppLocalizations l10n, {
  required JournalMeasure? measure,
  required DateTime? lastArchiveAt,
  required int? newSince,
  required String localeTag,
  DateTime? now,
}) {
  if (measure != null && measure.entries == 0) return l10n.backupNothingYet;
  final at = lastArchiveAt?.toLocal();
  final today = (now ?? DateTime.now()).toLocal();
  final backedUpToday =
      at != null && at.year == today.year && at.month == today.month && at.day == today.day;
  return [
    if (measure != null && measure.recordings > 0) l10n.backupRecordingCount(measure.recordings),
    if (measure != null && measure.approxBytes > 0) formatBytes(measure.approxBytes, localeTag),
    if (at == null)
      l10n.backupNoBackupYet
    else if (backedUpToday)
      l10n.backupToday
    else
      l10n.backupLastBackup(shortDateLabel(at, localeTag, now: today)),
    if (newSince != null && newSince > 0) l10n.backupNewSince(newSince),
  ].join(_dot);
}

/// What the top card's quiet line says. While a restore runs it is the
/// restore's: the picked file while it opens, the plan while it waits on
/// the user, to keep the app open while it writes, then what it did or why
/// it stopped. Otherwise a held backup outcome, else the facts.
ToneLine backupCardLine(
  AppLocalizations l10n,
  BackupState state, {
  required BackupNote? note,
  required String localeTag,
  DateTime? now,
}) {
  final told = switch (state.restore) {
    RestoreProbed(:final probe) || RestoreChecking(:final probe) => _fileLine(probe, localeTag),
    RestorePlanned(:final plan) => (text: restorePlanLine(l10n, plan), tone: NoteTone.quiet),
    RestoreRunning() => (text: l10n.restoreKeepOpen, tone: NoteTone.quiet),
    RestoreDone(:final summary) => (text: restoreDoneLine(l10n, summary), tone: NoteTone.positive),
    RestorePartial(:final plan, :final restored, :final reflectionsLeft) => (
      text: restorePartialLine(l10n, plan, restored, reflectionsLeft: reflectionsLeft),
      tone: NoteTone.negative,
    ),
    RestoreFailed(:final failure, :final probe) => (
      text: restoreFailureText(l10n, failure, probe: probe),
      tone: NoteTone.negative,
    ),
    RestoreIdle() || RestorePicking() => switch (note) {
      BackupArchiveNote(:final result, :final sealed) => _archiveLine(l10n, result, sealed: sealed),
      _ => null,
    },
  };
  return told ??
      (
        text: backupFacts(
          l10n,
          measure: state.measure,
          lastArchiveAt: state.lastArchiveAt,
          newSince: state.newSinceBackup,
          localeTag: localeTag,
          now: now,
        ),
        tone: NoteTone.quiet,
      );
}

/// The picked file as data, not copy: its own name and its size.
ToneLine _fileLine(ImportProbe probe, String localeTag) => (
  text: [probe.fileName, formatBytes(probe.sizeBytes, localeTag)].join(_dot),
  tone: NoteTone.quiet,
);

ToneLine _archiveLine(AppLocalizations l10n, BackupActionResult result, {required bool sealed}) =>
    result == BackupActionResult.shared
    ? (text: sealed ? l10n.backupDoneSealedNote : l10n.backupDoneNote, tone: NoteTone.positive)
    : (text: shareFailureLine(l10n, result), tone: NoteTone.negative);

/// What a plan would change that a reader would see, each part that is zero
/// left out: the entries it adds and replaces, the recordings it brings back,
/// and the reflections it updates. A plan that changes nothing seen says
/// everything is already here, even when it still brings the app's own state
/// up to date.
String restorePlanLine(AppLocalizations l10n, ImportPlan plan) {
  if (plan.changesNothingSeen) return l10n.restorePlanNothing;
  return [
    if (plan.added > 0) l10n.restorePlanAdds(plan.added),
    if (plan.replaced > 0) l10n.restorePlanReplaces(plan.replaced),
    if (plan.recordings > 0) l10n.restorePlanRecordings(plan.recordings),
    if (plan.reflections > 0) l10n.restorePlanReflections(plan.reflections),
  ].join(_dot);
}

/// What a finished restore did, each part a reader would see and that is
/// not zero, joined: no lead word, since the check and the ink say restored.
/// A restore that changed nothing seen, its own state brought up to date or
/// not, says everything was already here.
String restoreDoneLine(AppLocalizations l10n, ImportSummary summary) {
  final parts = [
    if (summary.entriesAdded > 0) l10n.restoreDoneAdded(summary.entriesAdded),
    if (summary.entriesReplaced > 0) l10n.restoreDoneReplaced(summary.entriesReplaced),
    if (summary.recordingsBroughtBack > 0)
      l10n.restoreDoneRecordings(summary.recordingsBroughtBack),
    if (summary.reflectionsUpdated > 0) l10n.restoreDoneReflections(summary.reflectionsUpdated),
  ];
  return parts.isEmpty ? l10n.restoreDoneNothing : parts.join(_dot);
}

/// What a restore that stopped partway did. A plan with no entry or
/// recording to count says so plainly, since "entries restored" would claim
/// work it never had. With every entry through adoption ([reflectionsLeft])
/// only the reflections are left, said in words. Otherwise it counts the
/// entries and recordings that landed against those planned, never more
/// than planned, since the journal may have moved on while the plan waited.
String restorePartialLine(
  AppLocalizations l10n,
  ImportPlan plan,
  ImportSummary restored, {
  required bool reflectionsLeft,
}) {
  final total = plan.added + plan.replaced + plan.recordings;
  if (total == 0) return l10n.restorePartialGeneric;
  if (reflectionsLeft) return l10n.restorePartialReflections;
  final done = restored.entriesAdded + restored.entriesReplaced + restored.recordingsBroughtBack;
  return l10n.restorePartialNote(done > total ? total : done, total);
}

/// Why a restore stopped before writing anything, in a short line. A file
/// that could not even be read has no probe. A read one is not a backup when
/// its bytes are no archive, or when it is a zip with no manifest, told as a
/// copy for other apps when it is laid out like one of the app's own; that
/// holds however the zip was compressed, so only a backup with compressed
/// entries reads as re-zipped. A full disk names itself; any other is a
/// backup that would not read.
String restoreFailureText(AppLocalizations l10n, RestoreFailure failure, {ImportProbe? probe}) =>
    switch ((failure, probe)) {
      (_, ImportProbe(contents: ZipContents.export)) => l10n.restoreExportNotBackup,
      (_, ImportProbe(contents: ZipContents.foreign)) => l10n.importNotArchive,
      (RestoreFailure.newerVersion, _) => l10n.importNewerVersion,
      (RestoreFailure.rezipped, _) => l10n.importRezipped,
      (RestoreFailure.noSpace, _) => l10n.restoreNoSpace,
      (RestoreFailure.damaged, null) => l10n.restoreUnopenable,
      (RestoreFailure.damaged, ImportProbe(kind: ArchiveKind.unknown)) => l10n.importNotArchive,
      (RestoreFailure.damaged, _) => l10n.restoreUnreadable,
    };

/// The leading capsule's face: the bar while a backup or a restore step
/// runs, else the words of what [capsule] stands for, inked as the card's
/// forward action.
MorphFace leadingFace(
  AppLocalizations l10n,
  BackupState state,
  Capsule capsule, {
  required String localeTag,
}) => capsule.action == CardAction.none
    ? _leadingBar(l10n, state, localeTag: localeTag)
    : MorphButton(label: _leadingWords(l10n, state, capsule.action));

/// What VoiceOver calls the leading capsule, in [leadingFace]'s order: a
/// bar's state in words, else the button's own.
String leadingSemanticLabel(
  AppLocalizations l10n,
  BackupState state,
  Capsule capsule, {
  required String localeTag,
}) {
  if (capsule.action != CardAction.none) return _leadingWords(l10n, state, capsule.action);
  final progress = state.progress;
  return switch (state.restore) {
    RestoreChecking(:final probe) => _checkingWord(l10n, probe),
    RestoreRunning(progress: final adopted) =>
      adopted == null
          ? l10n.restoreRunning
          : l10n.restoreRunningPercent(formatPercent(adopted, localeTag)),
    _ => switch (state.phase) {
      BackupPhase.sealing => l10n.backupEncrypting,
      BackupPhase.sharing => l10n.backupReadyToShare,
      BackupPhase.packing || null =>
        progress == null
            ? l10n.backupBackingUp
            : l10n.backupBackingUpPercent(formatPercent(progress, localeTag)),
    },
  };
}

/// The slim bar the leading capsule is while its capsule stands for nothing:
/// a restore step, else the running backup. A backup's has no measure
/// through the grace, its percent while it packs, then is full and still
/// while it seals and while the share sheet waits; a restore's checks or
/// unlocks with no measure, then fills with the adoption once the grace
/// passes.
MorphBar _leadingBar(AppLocalizations l10n, BackupState state, {required String localeTag}) {
  final progress = state.progress;
  return switch (state.restore) {
    RestoreChecking(:final probe) => MorphBar(fill: null, label: _checkingWord(l10n, probe)),
    RestoreRunning(progress: final adopted) => MorphBar(
      fill: adopted == null ? null : shownFraction(adopted),
      label: adopted == null ? '' : formatPercent(adopted, localeTag),
    ),
    _ => switch (state.phase) {
      BackupPhase.sealing => MorphBar(fill: 1, label: l10n.backupEncrypting),
      BackupPhase.sharing => MorphBar(fill: 1, label: l10n.backupReadyToShare),
      BackupPhase.packing || null => MorphBar(
        fill: progress == null ? null : shownFraction(progress),
        label: progress == null ? '' : formatPercent(progress, localeTag),
      ),
    },
  };
}

String _leadingWords(AppLocalizations l10n, BackupState state, CardAction action) =>
    switch (action) {
      CardAction.unlockRestore => l10n.importUnlock,
      CardAction.adoptRestore =>
        state.restore is RestorePartial ? l10n.restoreAgain : l10n.backupRestore,
      CardAction.dismissRestore => l10n.done,
      _ => l10n.backupBackUp,
    };

String _checkingWord(AppLocalizations l10n, ImportProbe probe) =>
    probe.kind == ArchiveKind.sealed ? l10n.restoreUnlocking : l10n.restoreChecking;

/// The trailing capsule's face, always the quiet way out of what the leading
/// one carries forward: the words of what [capsule] stands for.
MorphFace trailingFace(AppLocalizations l10n, BackupState state, Capsule capsule) => MorphButton(
  label: _trailingWords(l10n, state, capsule.action) ?? l10n.backupRestore,
  variant: MorphVariant.secondary,
);

/// What VoiceOver calls the trailing capsule: its words, or at rest the
/// longer name the bare "Restore" stands for.
String trailingSemanticLabel(AppLocalizations l10n, BackupState state, Capsule capsule) =>
    _trailingWords(l10n, state, capsule.action) ?? l10n.restoreBackupButton;

/// The words of a way out; null for Restore itself.
String? _trailingWords(AppLocalizations l10n, BackupState state, CardAction action) =>
    switch (action) {
      CardAction.closeAsk => l10n.exportCancel,
      CardAction.dismissRestore => state.restore is RestorePartial ? l10n.done : l10n.exportCancel,
      _ => null,
    };

/// Whether the trailing capsule keeps its seat beside [leading]: closed while
/// the leading one is a bar, which then takes the whole width, or is itself
/// the way out, as beside a plan with nothing in it.
bool trailingSeatOpen(Capsule leading) =>
    leading.action != CardAction.none && leading.action != CardAction.dismissRestore;

/// Whether the running backup can still be called off: only during the pack,
/// once its measure shows. A restore's adoption is never offered a cancel:
/// stopping it partway is the one outcome worth avoiding.
bool backupCancellable(BackupState state) =>
    state.busy == BackupBusy.archiving && state.progress != null;

/// Whether the restore's passphrase field is open: while a sealed file waits
/// for it, and while that passphrase is checked, so a wrong one comes back
/// to the same field rather than reopening it.
bool restoreAsksPassphrase(RestoreFlow flow) => switch (flow) {
  RestoreProbed() => true,
  RestoreChecking(:final probe) => probe.kind == ArchiveKind.sealed,
  _ => false,
};

/// How many passphrases have failed on the file waiting for one; 0 while
/// none has, and while one is checked.
int restoreUnlockAttempt(RestoreFlow flow) => flow is RestoreProbed ? flow.attempt : 0;

/// The backup card: the journal's count and quiet line on the model card's
/// face, the two capsules under it, a passphrase opening in place under them
/// (the backup's pair, or the restore's one to unlock a sealed file), and the
/// encryption switch below a hairline. Holds no state: the screen owns the
/// fields' text and whether the backup's are open, and the cubit owns the
/// restore.
class BackupCard extends StatelessWidget {
  const BackupCard({
    required this.state,
    required this.note,
    required this.asking,
    required this.passphrase,
    required this.repeat,
    required this.firstField,
    required this.unlock,
    required this.unlockField,
    required this.leading,
    required this.trailing,
    required this.onAct,
    required this.onCancelRun,
    required this.onSealChanged,
    required this.onPassphraseChanged,
    required this.onPassphraseSubmitted,
    required this.onUnlockSubmitted,
    super.key,
  });

  final BackupState state;
  final BackupNote? note;

  /// The backup's passphrase fields are open above the capsules.
  final bool asking;
  final TextEditingController passphrase;
  final TextEditingController repeat;

  /// The passphrase field focus lands in, so fields reopening before they
  /// folded away can bring the keyboard back.
  final FocusNode firstField;

  /// The restore's passphrase and its focus.
  final TextEditingController unlock;
  final FocusNode unlockField;

  /// What each capsule stands for and whether it is live ([leadingCapsule],
  /// [trailingCapsule]); a press hands its action to [onAct].
  final Capsule leading;
  final Capsule trailing;
  final ValueChanged<CardAction> onAct;
  final VoidCallback onCancelRun;

  /// Null leaves the encryption switch disabled.
  final ValueChanged<bool>? onSealChanged;

  /// Either passphrase changed, so what a capsule does may have.
  final VoidCallback onPassphraseChanged;
  final VoidCallback onPassphraseSubmitted;
  final VoidCallback onUnlockSubmitted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tag = localeTag(context);
    final title = backupTitle(l10n, state.measure);
    final line = backupCardLine(l10n, state, note: note, localeTag: tag);
    return SettingsCard(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: _Face(title: title, line: line),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The fields sit above the capsules so they open where the eye already is and
                  // push the capsules down.
                  AnimatedReveal(
                    visible: asking,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: PassphraseFields(
                        strings: PassphraseFieldStrings.seal(
                          placeholder: l10n.passphrasePlaceholder,
                          repeatPlaceholder: l10n.passphraseRepeatPlaceholder,
                          tooShort: l10n.passphraseTooShort,
                          mismatch: l10n.passphraseMismatch,
                          show: l10n.passphraseShow,
                          hide: l10n.passphraseHide,
                        ),
                        controller: passphrase,
                        repeatController: repeat,
                        focusNode: firstField,
                        onChanged: onPassphraseChanged,
                        onSubmitted: onPassphraseSubmitted,
                      ),
                    ),
                  ),
                  AnimatedReveal(
                    visible: restoreAsksPassphrase(state.restore),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: PassphraseFields(
                        strings: PassphraseFieldStrings.unlock(
                          placeholder: l10n.passphrasePlaceholder,
                          show: l10n.passphraseShow,
                          hide: l10n.passphraseHide,
                        ),
                        controller: unlock,
                        focusNode: unlockField,
                        errorText: l10n.importWrongPassphrase,
                        attempt: restoreUnlockAttempt(state.restore),
                        onChanged: onPassphraseChanged,
                        onSubmitted: onUnlockSubmitted,
                      ),
                    ),
                  ),
                  _Controls(
                    state: state,
                    leading: leading,
                    trailing: trailing,
                    onAct: onAct,
                    onCancelRun: onCancelRun,
                  ),
                ],
              ),
            ),
          ],
        ),
        SettingsToggleRow(
          icon: AppIcons.lock,
          label: l10n.backupSeal,
          value: state.seal,
          onChanged: onSealChanged,
        ),
      ],
    );
  }
}

/// The count with the journal's mark, over the quiet line, set as the model
/// card sets a model's name over its line. Each melts into its new self on
/// its own, on the control's clock, so a count that changes under a told
/// result leaves the result still.
class _Face extends StatelessWidget {
  const _Face({required this.title, required this.line});

  final String title;
  final ToneLine line;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Melt(
          child: _Title(key: ValueKey(title), title: title),
        ),
        SizedBox(height: theme.settings.noteGap),
        _Melt(
          child: _Line(key: ValueKey(line), line: line),
        ),
      ],
    );
  }
}

/// A part of the face swapping for its new self in place, the model card's
/// melt.
class _Melt extends StatelessWidget {
  const _Melt({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final motion = context.theme.motion;
    return AnimatedSwitcher(
      duration: context.reduceMotion ? Duration.zero : motion.indicator,
      switchInCurve: motion.indicatorCurve,
      switchOutCurve: motion.indicatorCurve.flipped,
      layoutBuilder: meltStack,
      child: child,
    );
  }
}

class _Title extends StatelessWidget {
  const _Title({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Row(
      children: [
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.headline.copyWith(color: theme.text),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        AppIcon(AppIcons.waveform, size: AppIconSize.body, color: theme.text),
      ],
    );
  }
}

/// The quiet line; a told outcome inks it, a positive one behind a check.
class _Line extends StatelessWidget {
  const _Line({required this.line, super.key});

  final ToneLine line;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final ink = noteToneInk(theme, line.tone) ?? theme.textSecondary;
    return Text.rich(
      TextSpan(
        children: [
          if (line.tone == NoteTone.positive)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: AppIcon(AppIcons.checkmark, size: AppIconSize.badge, color: ink),
              ),
            ),
          TextSpan(text: line.text),
        ],
      ),
      style: AppType.digits(AppType.rowNote).copyWith(color: ink),
    );
  }
}

/// The two capsules sharing the width: Back up and Restore at rest, each
/// taking the faces the card's state gives it. While the leading one is a
/// bar, the trailing seat closes on the bar's own clock and the bar takes the
/// whole width, its cancel disc beside it.
class _Controls extends StatelessWidget {
  const _Controls({
    required this.state,
    required this.leading,
    required this.trailing,
    required this.onAct,
    required this.onCancelRun,
  });

  final BackupState state;
  final Capsule leading;
  final Capsule trailing;
  final ValueChanged<CardAction> onAct;
  final VoidCallback onCancelRun;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tag = localeTag(context);
    return LayoutBuilder(
      builder: (context, constraints) => _SplitSeat(
        open: trailingSeatOpen(leading),
        width: constraints.maxWidth,
        leading: MorphControl(
          face: leadingFace(l10n, state, leading, localeTag: tag),
          semanticLabel: leadingSemanticLabel(l10n, state, leading, localeTag: tag),
          onPressed: leading.live ? () => onAct(leading.action) : null,
          cancellable: backupCancellable(state),
          onCancel: onCancelRun,
          cancelSemanticLabel: l10n.exportCancel,
        ),
        trailing: MorphControl(
          face: trailingFace(l10n, state, trailing),
          semanticLabel: trailingSemanticLabel(l10n, state, trailing),
          onPressed: trailing.live ? () => onAct(trailing.action) : null,
        ),
      ),
    );
  }
}

/// [leading] beside [trailing] at half the width each, the trailing seat
/// closing to nothing from its far edge when [open] turns false, and its
/// height easing from a button's to the slim bar's with it.
class _SplitSeat extends StatelessWidget {
  const _SplitSeat({
    required this.open,
    required this.width,
    required this.leading,
    required this.trailing,
  });

  final bool open;
  final double width;
  final Widget leading;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final button = theme.button;
    final motion = theme.motion;
    final half = (width - AppSpacing.md) / 2;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: open ? 1 : 0),
      duration: context.reduceMotion ? Duration.zero : motion.indicator,
      curve: motion.indicatorCurve,
      builder: (context, shown, _) => Row(
        children: [
          Expanded(child: leading),
          SizedBox(
            width: (half + AppSpacing.md) * shown,
            height: lerpDouble(button.bandHeight, button.height, shown),
            child: ClipRect(
              child: OverflowBox(
                minWidth: half,
                maxWidth: half,
                minHeight: button.height,
                maxHeight: button.height,
                alignment: Alignment.centerRight,
                // A closed seat is not a control: its capsule leaves the
                // semantics tree with it.
                child: ExcludeSemantics(
                  excluding: !open,
                  child: Opacity(opacity: shown.clamp(0.0, 1.0), child: trailing),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
