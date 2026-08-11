import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/app/deps.dart';
import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/models/exporter_descriptor.dart';
import 'package:opentranscribe/core/services/backup_settings.dart';
import 'package:opentranscribe/core/services/export_service.dart';
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

/// The format choice persists as the shared last-used format, so the Backup
/// screen and this sheet stay one memory. The composition-root reach-in
/// happens here, once, so the body is plain.
Future<void> showEntryExportSheet(BuildContext context, Entry entry) => showAppSheet<void>(
  context,
  builder: (context) => _EntryExportSheetBody(
    entry: entry,
    descriptors: Deps.i.exporterDescriptors,
    settings: Deps.i.backupSettings,
    export: Deps.i.exportService,
  ),
);

class _EntryExportSheetBody extends StatefulWidget {
  const _EntryExportSheetBody({
    required this.entry,
    required this.descriptors,
    required this.settings,
    required this.export,
  });

  final Entry entry;
  final List<ExporterDescriptor> descriptors;
  final BackupSettings settings;
  final ExportService export;

  @override
  State<_EntryExportSheetBody> createState() => _EntryExportSheetBodyState();
}

class _EntryExportSheetBodyState extends State<_EntryExportSheetBody> {
  late String _formatId;
  late bool _includeAudio;
  bool _busy = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _formatId = resolveFormatId(widget.settings.formatId, widget.descriptors);
    _includeAudio = widget.entry.hasAudio;
  }

  Future<void> _export() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failed = false;
    });
    final strings = exportStringsOf(AppLocalizations.of(context)!);
    try {
      await widget.settings.setFormatId(_formatId);
      final shared = await widget.export.shareEntry(
        widget.entry.id,
        exporterId: _formatId,
        includeAudio: _includeAudio,
        strings: strings,
      );
      if (!mounted) return;
      // A cancelled share stays put: the user may only be changing the
      // format or the audio toggle.
      if (shared) {
        Navigator.of(context).pop();
      } else {
        setState(() => _busy = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    return SheetMessage(
      icon: AppIcons.squareAndArrowUp,
      title: l10n.exportEntryTitle,
      rows: [
        SettingsCard(
          children: [
            for (final descriptor in widget.descriptors)
              ExportFormatRow(
                descriptor: descriptor,
                selected: descriptor.exporterId == _formatId,
                onTap: _busy ? null : () => setState(() => _formatId = descriptor.exporterId),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        SettingsCard(
          children: [
            SettingsToggleRow(
              icon: AppIcons.micFill,
              label: l10n.exportIncludeAudio,
              value: _includeAudio,
              onChanged: widget.entry.hasAudio && !_busy
                  ? (v) => setState(() => _includeAudio = v)
                  : null,
            ),
          ],
        ),
        if (_failed) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(l10n.exportFailedBody, style: AppType.footnote.copyWith(color: theme.danger)),
        ],
      ],
      action: AppButton(label: l10n.exportEntry, isLoading: _busy, onPressed: _export),
    );
  }
}
