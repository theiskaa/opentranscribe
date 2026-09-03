import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:opentranscribe/core/app/deps.dart';
import 'package:opentranscribe/core/export/archive_codec.dart';
import 'package:opentranscribe/core/models/exporter_descriptor.dart';
import 'package:opentranscribe/core/services/export_service.dart';
import 'package:opentranscribe/core/state/backup_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/core/utils/haptics.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/app_button.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/app_scaffold.dart';
import 'package:opentranscribe/view/widgets/app_sheet.dart';
import 'package:opentranscribe/view/widgets/app_spinner.dart';
import 'package:opentranscribe/view/widgets/export_format_row.dart';
import 'package:opentranscribe/view/widgets/export_l10n.dart';
import 'package:opentranscribe/view/widgets/formatting.dart';
import 'package:opentranscribe/view/widgets/glass_fab.dart';
import 'package:opentranscribe/view/widgets/passphrase_sheet.dart';
import 'package:opentranscribe/view/widgets/settings_kit.dart';
import 'package:opentranscribe/view/widgets/sheet_message.dart';

/// Backup: the restorable native archive out and back in, and the one-way
/// formatted exports, one action row per format. Owns a [BackupCubit] so the
/// journal is measured on every open.
class BackupScreen extends StatelessWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => BackupCubit(
        service: Deps.i.transcriptionService,
        export: Deps.i.exportService,
        import: Deps.i.importService,
        settings: Deps.i.backupSettings,
        descriptors: Deps.i.exporterDescriptors,
      )..load(),
      child: const _BackupView(),
    );
  }
}

class _BackupView extends StatefulWidget {
  const _BackupView();

  @override
  State<_BackupView> createState() => _BackupViewState();
}

class _BackupViewState extends State<_BackupView> {
  /// Null until the user decides; the default follows the measure whenever
  /// it lands, and an unmeasured journal reads as having audio, because a
  /// silent all-audio omission is the worse wrong default.
  bool? _includeAudio;

  /// The format row whose export is running, so only it wears the spinner.
  String? _exportingId;

  bool _hasRecordings(BackupState state) => (state.measure?.recordings ?? 1) > 0;

  Future<void> _exportJournal(BuildContext context, ExporterDescriptor descriptor) async {
    final cubit = context.read<BackupCubit>();
    if (cubit.state.isBusy) return;
    final strings = exportStringsOf(AppLocalizations.of(context)!);
    setState(() => _exportingId = descriptor.exporterId);
    final result = await cubit.exportJournal(
      strings: strings,
      exporterId: descriptor.exporterId,
      includeAudio: _includeAudio ?? _hasRecordings(cubit.state),
    );
    if (mounted) setState(() => _exportingId = null);
    if (!context.mounted) return;
    unawaited(_shareFailSheet(context, result));
  }

  /// Nothing for the quiet outcomes; each failure names its cause where the
  /// cubit could tell it apart.
  Future<void> _shareFailSheet(BuildContext context, BackupActionResult result) {
    final l10n = AppLocalizations.of(context)!;
    return switch (result) {
      BackupActionResult.shared || BackupActionResult.cancelled => Future<void>.value(),
      BackupActionResult.failed => _failSheet(context, export: true),
      BackupActionResult.failedTooLarge => _failSheet(
        context,
        export: true,
        body: l10n.exportTooLargeBody,
      ),
      BackupActionResult.failedNoSpace => _failSheet(
        context,
        export: true,
        body: l10n.exportNoSpaceBody,
      ),
    };
  }

  Future<void> _saveArchive(BuildContext context) async {
    final cubit = context.read<BackupCubit>();
    if (cubit.state.isBusy) return;
    final l10n = AppLocalizations.of(context)!;
    String? passphrase;
    if (cubit.state.seal) {
      passphrase = await showPassphraseSheet(
        context,
        strings: PassphraseSheetStrings.seal(
          title: l10n.passphraseCreateTitle,
          body: l10n.passphraseCreateBody,
          placeholder: l10n.passphrasePlaceholder,
          repeatPlaceholder: l10n.passphraseRepeatPlaceholder,
          actionLabel: l10n.backupSave,
          tooShort: l10n.passphraseTooShort,
          mismatch: l10n.passphraseMismatch,
          show: l10n.passphraseShow,
          hide: l10n.passphraseHide,
        ),
      );
      if (passphrase == null || !context.mounted) return;
    }
    final result = await cubit.exportArchive(passphrase: passphrase);
    if (!context.mounted) return;
    unawaited(_shareFailSheet(context, result));
  }

  /// Each decision is a sheet; the cubit holds the busy gate and the outcomes.
  Future<void> _import(BuildContext context) async {
    final cubit = context.read<BackupCubit>();
    if (cubit.state.isBusy) return;
    final path = await cubit.pickArchive();
    if (path == null || !context.mounted) return;
    try {
      await _importPicked(context, cubit, path);
    } finally {
      unawaited(cubit.discardPicked(path));
    }
  }

  Future<void> _importPicked(BuildContext context, BackupCubit cubit, String path) async {
    final l10n = AppLocalizations.of(context)!;
    final locale = localeTag(context);
    final probe = await cubit.probeArchive(path);
    if (!context.mounted) return;
    // An unreadable file is not evidence about what it is: only a file whose
    // bytes were read and rejected earns the "not a backup" verdict.
    if (probe == null) {
      await _failSheet(context, body: l10n.importFailedBody);
      return;
    }
    if (probe.kind == ArchiveKind.unknown) {
      await _failSheet(context, body: l10n.importNotArchive);
      return;
    }
    final confirmed = await showAppSheet<bool>(
      context,
      builder: (context) => SheetMessage(
        icon: AppIcons.squareAndArrowDown,
        title: l10n.importConfirmTitle,
        body: l10n.importConfirmBody,
        rows: [
          _ArchiveFactRow(label: probe.fileName, detail: formatBytes(probe.sizeBytes, locale)),
          if (probe.counts != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                l10n.importConfirmCounts(probe.counts!.entries, probe.counts!.audio),
                style: AppType.subhead.copyWith(color: context.theme.textSecondary, height: 1.5),
              ),
            ),
        ],
        action: AppButton(
          label: l10n.importConfirm,
          onPressed: () {
            Haptics.medium();
            Navigator.of(context).pop(true);
          },
        ),
      ),
    );
    if (!(confirmed ?? false) || !context.mounted) return;

    String? wrongPassphrase;
    while (true) {
      if (!context.mounted) return;
      String? passphrase;
      if (probe.kind == ArchiveKind.sealed) {
        passphrase = await showPassphraseSheet(
          context,
          strings: PassphraseSheetStrings.unlock(
            title: l10n.importUnlockTitle,
            body: l10n.importUnlockBody,
            placeholder: l10n.passphrasePlaceholder,
            actionLabel: l10n.importUnlock,
            show: l10n.passphraseShow,
            hide: l10n.passphraseHide,
          ),
          errorText: wrongPassphrase,
        );
        if (passphrase == null || !context.mounted) return;
      }
      final outcome = await cubit.importArchive(path, passphrase: passphrase);
      if (outcome == null || !context.mounted) return;
      switch (outcome.resolution) {
        case ImportResolution.success:
          await _summarySheet(context, outcome);
          return;
        case ImportResolution.retryPassphrase when probe.kind == ArchiveKind.sealed:
          wrongPassphrase = l10n.importWrongPassphrase;
        case ImportResolution.retryPassphrase:
          await _failSheet(context, body: l10n.importFailedBody);
          return;
        case ImportResolution.failedNewerVersion:
          await _failSheet(context, body: l10n.importNewerVersion);
          return;
        case ImportResolution.failedRezipped:
          await _failSheet(context, body: l10n.importRezipped);
          return;
        case ImportResolution.failed:
          await _failSheet(context, body: l10n.importFailedBody);
          return;
        case ImportResolution.failedMidway:
          await _failSheet(context, body: l10n.importFailedMidway);
          return;
      }
    }
  }

  Future<void> _summarySheet(BuildContext context, ImportOutcome outcome) {
    final l10n = AppLocalizations.of(context)!;
    final summary = outcome.summary!;
    final replaced = summary.entriesUpdated;
    final skipped = summary.entriesUnchanged;
    final audio = summary.audioRestored;
    return showAppSheet<void>(
      context,
      builder: (context) {
        final theme = context.theme;
        final detail = AppType.subhead.copyWith(color: theme.textSecondary, height: 1.5);
        // The detail lines stand alone rather than being space-joined onto
        // the body: ja and zh sentences take no separator.
        return SheetMessage(
          icon: AppIcons.checkmark,
          title: l10n.importSummaryTitle,
          body: l10n.importSummaryAdded(summary.entriesAdded),
          rows: [
            if (audio > 0) Text(l10n.importSummaryAudio(audio), style: detail),
            if (replaced > 0) Text(l10n.importSummaryReplaced(replaced), style: detail),
            if (skipped > 0) Text(l10n.importSummarySkipped(skipped), style: detail),
          ],
          action: AppButton(
            label: l10n.done,
            variant: AppButtonVariant.secondary,
            onPressed: () => Navigator.of(context).pop(),
          ),
        );
      },
    );
  }

  Future<void> _failSheet(BuildContext context, {String? body, bool export = false}) {
    final l10n = AppLocalizations.of(context)!;
    return showAppSheet<void>(
      context,
      builder: (context) => SheetMessage(
        icon: AppIcons.xmark,
        title: export ? l10n.exportFailedTitle : l10n.importFailedTitle,
        body: body ?? l10n.exportFailedBody,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    final locale = localeTag(context);
    final cubit = context.read<BackupCubit>();
    final state = context.watch<BackupCubit>().state;

    // Busy never greys this screen: handlers refuse re-entry themselves and
    // the running row wears the spinner, so nothing flashes half-faded.
    // An empty journal disables saving and exporting, never restore; unknown
    // reads as non-empty so nothing flashes disabled while measuring.
    final hasEntries = (state.measure?.entries ?? 1) > 0;
    final hasRecordings = _hasRecordings(state);

    // Import is the one operation with no system UI covering the screen; a
    // pop mid-adopt would orphan the summary and unseat the busy gate.
    // PopScope covers the edge swipe the hidden back button cannot.
    final canLeave = state.busy != BackupBusy.importing;
    return PopScope(
      canPop: canLeave,
      child: AppScaffold(
        background: theme.screens.settings,
        onBack: canLeave ? () => context.pop() : null,
        child: Stack(
          children: [
            SettingsList(
              children: [
                const SizedBox(height: 10),
                SectionInfo(_intro(l10n, locale, state.measure)),
                SettingsCard(
                  children: [
                    SettingsToggleRow(
                      icon: AppIcons.lock,
                      label: l10n.backupSeal,
                      value: state.seal,
                      onChanged: (seal) => unawaited(cubit.setSeal(seal)),
                    ),
                    SettingsBusyRow(
                      icon: AppIcons.squareAndArrowUp,
                      label: l10n.backupSave,
                      detail: _saveDetail(l10n, locale, state),
                      // The spinner yields to the percent once ticks arrive:
                      // the row renders one or the other, never both.
                      busy: state.busy == BackupBusy.archiving && state.progress == null,
                      onTap: hasEntries ? () => unawaited(_saveArchive(context)) : null,
                    ),
                    if (state.busy == BackupBusy.archiving && state.progress != null)
                      SettingsBusyRow(
                        icon: AppIcons.xmark,
                        label: l10n.exportCancel,
                        busy: false,
                        tint: theme.danger,
                        onTap: cubit.cancelShare,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                SectionLabel(l10n.backupExportSection),
                SettingsCard(
                  children: [
                    SettingsToggleRow(
                      icon: AppIcons.micFill,
                      label: l10n.exportIncludeAudio,
                      value: (_includeAudio ?? hasRecordings) && hasRecordings,
                      onChanged: hasRecordings ? (v) => setState(() => _includeAudio = v) : null,
                    ),
                    for (final descriptor in cubit.descriptors)
                      ExportFormatRow(
                        descriptor: descriptor,
                        selected: false,
                        dimmed: !hasEntries,
                        label: l10n.backupExportAs(exportFormatCopy(l10n, descriptor.format).name),
                        busy:
                            state.busy == BackupBusy.exporting &&
                            _exportingId == descriptor.exporterId,
                        onTap: hasEntries
                            ? () => unawaited(_exportJournal(context, descriptor))
                            : null,
                      ),
                    if (state.busy == BackupBusy.exporting && state.progress != null)
                      SettingsBusyRow(
                        icon: AppIcons.xmark,
                        label: l10n.exportCancel,
                        detail: NumberFormat.percentPattern(locale).format(state.progress),
                        busy: false,
                        tint: theme.danger,
                        onTap: cubit.cancelShare,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                SectionInfo(l10n.backupExportInfo),
              ],
            ),
            // Restore floats like every entry point that reaches outside the
            // app does; it is the one action here that picks a file from
            // beyond the journal.
            Positioned(
              right: AppSpacing.xl,
              bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.xl,
              child: _RestoreFab(
                busy: state.busy == BackupBusy.importing,
                onTap: () {
                  Haptics.light();
                  unawaited(_import(context));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The percent takes the detail while the pack runs; the date is
  /// yesterday's news next to a backup being written.
  String? _saveDetail(AppLocalizations l10n, String locale, BackupState state) {
    if (state.busy == BackupBusy.archiving) {
      final progress = state.progress;
      return progress == null ? null : NumberFormat.percentPattern(locale).format(progress);
    }
    final at = state.lastArchiveAt;
    if (at == null) return null;
    return l10n.backupLastBackup(DateFormat.yMMMd(locale).format(at.toLocal()));
  }

  /// Generic until the first measure lands, "nothing yet" for an empty
  /// journal, and the counted-and-weighed line once there is something.
  String _intro(AppLocalizations l10n, String locale, JournalMeasure? measure) {
    if (measure == null) return l10n.backupInfo;
    if (measure.entries == 0) return l10n.backupInfoEmpty;
    return l10n.backupInfoMeasured(measure.entries, formatBytes(measure.approxBytes, locale));
  }
}

/// The restore disc: [GlassFab] wearing the import glyph, its seat taken
/// whole by a spinner while the restore runs. The spinner replaces rather
/// than overlays, because the glass disc is a platform view on iOS 26 and
/// would not honour an opacity above it.
class _RestoreFab extends StatelessWidget {
  const _RestoreFab({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // 22, under the waveform's 26: the boxy glyph carries far more ink per
    // point, and at the disc's default it crowds the circle.
    if (!busy) {
      return GlassFab(
        icon: AppIcons.squareAndArrowDown,
        iconSize: 22,
        semanticLabel: AppLocalizations.of(context)!.restoreBackupButton,
        onTap: onTap,
      );
    }
    return SizedBox.square(
      dimension: GlassFab.size,
      child: Center(child: AppSpinner(size: 24, color: context.theme.textSecondary)),
    );
  }
}

/// Raw strings by design: a filename is data, not copy.
class _ArchiveFactRow extends StatelessWidget {
  const _ArchiveFactRow({required this.label, required this.detail});

  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppType.subhead.copyWith(color: theme.text),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Text(detail, style: AppType.digits(AppType.subhead).copyWith(color: theme.textSecondary)),
      ],
    );
  }
}
