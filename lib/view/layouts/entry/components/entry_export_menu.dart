import 'package:flutter/foundation.dart' show Uint8List;

import 'package:opentranscribe/core/models/exporter_descriptor.dart';
import 'package:opentranscribe/core/state/backup_cubit.dart';
import 'package:opentranscribe/core/theming/app_icons.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/app_menu.dart';

/// The Export row's own id; on native it never fires, on the fallback it
/// opens the formats as a follow-up menu.
const entryExportId = 'act:export';

/// The Include audio check inside the Export submenu.
const entryExportAudioId = 'export:audio';

const _formatPrefix = 'export:format:';

/// The id a format's row answers with.
String entryExportFormatItemId(String exporterId) => '$_formatPrefix$exporterId';

/// The exporter a format row's [id] names; null for any other id.
String? entryExportFormatOf(String id) =>
    id.startsWith(_formatPrefix) ? id.substring(_formatPrefix.length) : null;

/// The entry menu's Export row: a submenu of the formats in registry order,
/// each wearing its mark once [marks] has it, then, in a section of its own,
/// the Include audio check for an entry with a recording. The check keeps the
/// menu up, so it lives in the submenu: a held-open toggle repaints only there.
AppMenuItem entryExportMenuItem({
  required List<ExporterDescriptor> descriptors,
  required String Function(ExportFormat format) nameOf,
  required Map<String, Uint8List> marks,
  required bool hasAudio,
  required bool includeAudio,
  required String label,
  required String includeAudioLabel,
}) => AppMenuItem(
  id: entryExportId,
  label: label,
  icon: AppIcons.squareAndArrowUp,
  children: [
    for (final descriptor in descriptors)
      AppMenuItem(
        id: entryExportFormatItemId(descriptor.exporterId),
        label: nameOf(descriptor.format),
        iconBytes: marks[descriptor.exporterId],
      ),
    if (hasAudio) ...[
      const AppMenuItem.divider(),
      AppMenuItem(
        id: entryExportAudioId,
        label: includeAudioLabel,
        selected: includeAudio,
        keepsPresented: true,
      ),
    ],
  ],
);

/// The bar's short word for a failed export. The two causes a user can act
/// on keep their name; anything else is the plain failure.
String entryExportFailureLabel(AppLocalizations l10n, BackupActionResult result) =>
    switch (result) {
      BackupActionResult.failedTooLarge => l10n.exportEntryTooLarge,
      BackupActionResult.failedNoSpace => l10n.exportEntryNoSpace,
      BackupActionResult.shared ||
      BackupActionResult.cancelled ||
      BackupActionResult.failed => l10n.exportEntryFailed,
    };
