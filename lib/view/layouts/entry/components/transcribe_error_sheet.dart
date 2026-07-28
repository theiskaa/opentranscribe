import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/entries_cubit.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/app_button.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/app_sheet.dart';
import 'package:opentranscribe/view/widgets/sheet_message.dart';

/// Opens the full story behind a transcription failure and returns whether the
/// user asked to try again. The retry runs on the caller's side, AFTER the sheet
/// has closed, so its work lands on the screen and not under a modal.
Future<bool> showTranscribeErrorSheet(BuildContext context, EntriesError kind) async {
  final retry = await showAppSheet<bool>(context, builder: (context) => _ErrorContent(kind: kind));
  return retry ?? false;
}

/// The words for each failure kind: the icon it wears, the sheet's title, and
/// the detailed body (reused from the notice strings, which already explain the
/// fix in full).
(IconData, String, String) _story(EntriesError kind, AppLocalizations l10n) => switch (kind) {
  EntriesError.permissionDenied => (
    AppIcons.mic,
    l10n.transcribeErrorTitlePermission,
    l10n.transcribeErrorPermission,
  ),
  EntriesError.onDeviceUnavailable => (
    AppIcons.globe,
    l10n.transcribeErrorTitleUnavailable,
    l10n.transcribeErrorUnavailable,
  ),
  EntriesError.modelInstallFailed => (
    AppIcons.icloud,
    l10n.transcribeErrorTitleModelInstall,
    l10n.transcribeErrorModelInstall,
  ),
  EntriesError.reservationCap => (
    AppIcons.globe,
    l10n.transcribeErrorTitleCapReached,
    l10n.transcribeErrorCapReached,
  ),
  EntriesError.generic => (
    AppIcons.waveform,
    l10n.transcribeErrorTitleGeneric,
    l10n.transcribeErrorGeneric,
  ),
};

class _ErrorContent extends StatelessWidget {
  const _ErrorContent({required this.kind});

  final EntriesError kind;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final (icon, title, body) = _story(kind, l10n);

    return SheetMessage(
      icon: icon,
      title: title,
      body: body,
      action: AppButton(label: l10n.retry, onPressed: () => Navigator.of(context).pop(true)),
    );
  }
}
