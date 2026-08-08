import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:opentranscribe/core/app/deps.dart';
import 'package:opentranscribe/core/export/archive_codec.dart';
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
import 'package:opentranscribe/view/widgets/export_l10n.dart';
import 'package:opentranscribe/view/widgets/exporter_logo.dart';
import 'package:opentranscribe/view/widgets/formatting.dart';
import 'package:opentranscribe/view/widgets/glass_icon_button.dart';
import 'package:opentranscribe/view/widgets/passphrase_sheet.dart';
import 'package:opentranscribe/view/widgets/settings_kit.dart';
import 'package:opentranscribe/view/widgets/sheet_message.dart';

/// Backup: the whole journal out through the share sheet (a chosen format, or
/// the native archive, sealed on request) and a native archive back in. Owns
/// a [BackupCubit] so the entry count is measured on every open.
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

class _BackupView extends StatelessWidget {
  const _BackupView();

  Future<void> _exportJournal(BuildContext context) async {
    final cubit = context.read<BackupCubit>();
    final strings = exportStringsOf(AppLocalizations.of(context)!);
    final result = await cubit.exportJournal(strings);
    if (!context.mounted) return;
    if (result == BackupActionResult.failed) unawaited(_failSheet(context, export: true));
  }

  Future<void> _saveArchive(BuildContext context) async {
    final cubit = context.read<BackupCubit>();
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
        ),
      );
      if (passphrase == null || !context.mounted) return;
    }
    final result = await cubit.exportArchive(passphrase: passphrase);
    if (!context.mounted) return;
    if (result == BackupActionResult.failed) unawaited(_failSheet(context, export: true));
  }

  /// Each decision is a sheet; the cubit holds the busy gate and the outcomes.
  Future<void> _import(BuildContext context) async {
    final cubit = context.read<BackupCubit>();
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
    if (probe == null || probe.kind == ArchiveKind.unknown) {
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
    final skipped = summary.entriesUnchanged;
    return showAppSheet<void>(
      context,
      builder: (context) {
        final theme = context.theme;
        // The skipped line stands alone rather than being space-joined onto
        // the body: ja and zh sentences take no separator.
        return SheetMessage(
          icon: AppIcons.checkmark,
          title: l10n.importSummaryTitle,
          body: l10n.importSummaryImported(summary.entriesImported),
          rows: [
            if (skipped > 0)
              Text(
                l10n.importSummarySkipped(skipped),
                style: AppType.subhead.copyWith(color: theme.textSecondary, height: 1.5),
              ),
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
    final idle = !state.isBusy;

    // Import is the one operation with no system UI covering the screen; a
    // pop mid-adopt would orphan the summary and unseat the busy gate.
    // PopScope covers the edge swipe the hidden back button cannot.
    final canLeave = state.busy != BackupBusy.importing;
    return PopScope(
      canPop: canLeave,
      child: AppScaffold(
        background: theme.screens.settings,
        onBack: canLeave ? () => context.pop() : null,
        actions: [
          _RestoreAction(
            busy: state.busy == BackupBusy.importing,
            onTap: idle ? () => unawaited(_import(context)) : null,
          ),
        ],
        child: SettingsList(
          children: [
            const SizedBox(height: 10),
            SectionInfo(
              state.entryCount == null ? l10n.backupInfo : l10n.backupInfoCount(state.entryCount!),
            ),
            SettingsCard(
              children: [
                SettingsToggleRow(
                  icon: AppIcons.lock,
                  label: l10n.backupSeal,
                  value: state.seal,
                  onChanged: idle ? (seal) => unawaited(cubit.setSeal(seal)) : null,
                ),
                SettingsBusyRow(
                  icon: AppIcons.squareAndArrowUp,
                  label: l10n.backupSave,
                  detail: state.lastArchiveAt == null
                      ? null
                      : l10n.backupLastBackup(
                          DateFormat.yMMMd(locale).format(state.lastArchiveAt!.toLocal()),
                        ),
                  busy: state.busy == BackupBusy.archiving,
                  onTap: idle ? () => unawaited(_saveArchive(context)) : null,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            SectionLabel(l10n.backupExportSection),
            SettingsCard(
              children: [
                for (final descriptor in cubit.descriptors)
                  SelectableRow(
                    label: exporterDisplayName(descriptor, l10n),
                    leading: ExporterLogo(descriptor),
                    selected: descriptor.exporterId == state.formatId,
                    onTap: idle ? () => unawaited(cubit.setFormat(descriptor.exporterId)) : null,
                  ),
                const SettingsDivider(),
                SettingsBusyRow(
                  icon: AppIcons.squareAndArrowUp,
                  label: l10n.backupExportJournal,
                  busy: state.busy == BackupBusy.exporting,
                  onTap: idle ? () => unawaited(_exportJournal(context)) : null,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            SectionInfo(l10n.backupExportInfo),
          ],
        ),
      ),
    );
  }
}

/// Restore on the bar, not in a card: it is the one action here that reaches
/// for a file from outside the app. The spinner takes the button's whole seat
/// rather than fading over it, because the glass button is a platform view on
/// iOS 26 and would not honour an opacity above it.
class _RestoreAction extends StatelessWidget {
  const _RestoreAction({required this.busy, required this.onTap});

  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.theme.topBar;
    return SizedBox.square(
      dimension: tokens.actionSize,
      child: busy
          ? Center(
              child: AppSpinner(size: tokens.backChevronSize, color: tokens.iconColor),
            )
          : AppGlassIconButton(
              icon: AppIcons.squareAndArrowDown,
              size: tokens.actionSize,
              color: tokens.iconColor,
              onTap: onTap,
            ),
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
