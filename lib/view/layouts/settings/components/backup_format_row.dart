import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/models/exporter_descriptor.dart';
import 'package:opentranscribe/core/state/backup_cubit.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/layouts/settings/components/backup_rules.dart';
import 'package:opentranscribe/view/widgets/export_format_row.dart';
import 'package:opentranscribe/view/widgets/export_l10n.dart';
import 'package:opentranscribe/view/widgets/settings_kit.dart';

/// How one format's row shows the journal export: whether it is this row's
/// that runs, whether its files wait on the share sheet, and how far its pack
/// has come.
typedef ExportRowRun = ({bool running, bool waiting, double? fraction});

/// [ExportRowRun] for [exporterId]'s row: idle unless the running export is
/// this format's.
ExportRowRun exportRowRun(BackupState state, String exporterId) {
  final running = state.busy == BackupBusy.exporting && state.exportingId == exporterId;
  return (
    running: running,
    waiting: running && state.phase == BackupPhase.sharing,
    fraction: running ? state.progress : null,
  );
}

/// What a format row's note says in place of the format's own line: where
/// the files go while the share sheet waits on them, else the outcome of the
/// row's last export, or null for nothing to tell.
ToneLine? exportRowLine(
  AppLocalizations l10n,
  BackupNote? note,
  String exporterId, {
  bool waiting = false,
}) {
  if (waiting) return (text: l10n.exportChooseWhereNote, tone: NoteTone.quiet);
  return switch (note) {
    BackupExportNote(exporterId: final id, :final result) when id == exporterId =>
      result == BackupActionResult.shared
          ? (text: l10n.exportSharedNote, tone: NoteTone.positive)
          : (text: shareFailureLine(l10n, result), tone: NoteTone.negative),
    _ => null,
  };
}

/// One format's export row on the Backup screen: the shared action row, fed
/// this format's run and its last outcome.
class BackupFormatRow extends StatelessWidget {
  const BackupFormatRow({
    required this.descriptor,
    required this.state,
    required this.note,
    required this.onTap,
    required this.onCancel,
    super.key,
  });

  final ExporterDescriptor descriptor;
  final BackupState state;
  final BackupNote? note;

  /// Null disables the row.
  final VoidCallback? onTap;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final run = exportRowRun(state, descriptor.exporterId);
    final told = exportRowLine(l10n, note, descriptor.exporterId, waiting: run.waiting);
    return ExportFormatRow(
      descriptor: descriptor,
      onTap: onTap,
      note: told?.text,
      noteTone: told?.tone ?? NoteTone.quiet,
      running: run.running,
      waiting: run.waiting,
      fraction: run.fraction,
      onCancel: onCancel,
      cancelSemanticLabel: l10n.exportCancel,
    );
  }
}
