import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/state/backup_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/app_icons.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/app_button.dart';
import 'package:opentranscribe/view/widgets/app_sheet.dart';
import 'package:opentranscribe/view/widgets/export_format_row.dart';
import 'package:opentranscribe/view/widgets/export_l10n.dart';
import 'package:opentranscribe/view/widgets/settings_kit.dart';
import 'package:opentranscribe/view/widgets/sheet_message.dart';

/// The journal export decision, taken at export time the way the entry sheet
/// takes it: format, whether audio rides along, one action. The chosen
/// format persists as the shared last-used format only once the export
/// actually ran, so both sheets stay one memory under one rule.
Future<void> showJournalExportSheet(BuildContext context, BackupCubit cubit) => showAppSheet<void>(
  context,
  builder: (_) => BlocProvider.value(value: cubit, child: const _JournalExportSheetBody()),
);

class _JournalExportSheetBody extends StatefulWidget {
  const _JournalExportSheetBody();

  @override
  State<_JournalExportSheetBody> createState() => _JournalExportSheetBodyState();
}

class _JournalExportSheetBodyState extends State<_JournalExportSheetBody> {
  late String _formatId;

  /// Null until the user decides; the default follows the measure whenever
  /// it lands, and an unmeasured journal reads as having audio, because a
  /// silent all-audio omission is the worse wrong default.
  bool? _includeAudio;

  /// Null while nothing failed; otherwise the failure the footnote names.
  BackupActionResult? _failure;

  @override
  void initState() {
    super.initState();
    _formatId = context.read<BackupCubit>().state.formatId;
  }

  bool _hasRecordings(BackupState state) => (state.measure?.recordings ?? 1) > 0;

  Future<void> _export() async {
    final cubit = context.read<BackupCubit>();
    if (cubit.state.isBusy) return;
    setState(() => _failure = null);
    final strings = exportStringsOf(AppLocalizations.of(context)!);
    final result = await cubit.exportJournal(
      strings: strings,
      exporterId: _formatId,
      includeAudio: _includeAudio ?? _hasRecordings(cubit.state),
    );
    if (!mounted) return;
    if (result == BackupActionResult.shared) {
      Navigator.of(context).pop();
    } else if (result != BackupActionResult.cancelled) {
      // A cancelled share stays put: the user may only be changing the
      // format or the audio toggle.
      setState(() => _failure = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    final cubit = context.read<BackupCubit>();
    return BlocBuilder<BackupCubit, BackupState>(
      builder: (context, state) {
        final busy = state.isBusy;
        final hasRecordings = _hasRecordings(state);
        final includeAudio = _includeAudio ?? hasRecordings;
        return SheetMessage(
          icon: AppIcons.squareAndArrowUp,
          title: l10n.backupExportJournal,
          rows: [
            SettingsCard(
              children: [
                for (final descriptor in cubit.descriptors)
                  ExportFormatRow(
                    descriptor: descriptor,
                    selected: descriptor.exporterId == _formatId,
                    onTap: busy ? null : () => setState(() => _formatId = descriptor.exporterId),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            SettingsCard(
              children: [
                SettingsToggleRow(
                  icon: AppIcons.micFill,
                  label: l10n.exportIncludeAudio,
                  value: includeAudio && hasRecordings,
                  onChanged: hasRecordings && !busy
                      ? (v) => setState(() => _includeAudio = v)
                      : null,
                ),
              ],
            ),
            if (_failure != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                shareFailureLine(l10n, _failure!),
                style: AppType.footnote.copyWith(color: theme.danger),
              ),
            ],
          ],
          action: AppButton(
            label: l10n.exportEntry,
            isLoading: state.busy == BackupBusy.exporting,
            onPressed: _export,
          ),
        );
      },
    );
  }
}
