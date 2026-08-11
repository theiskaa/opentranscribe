import 'package:flutter/widgets.dart';

import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/app_button.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/app_sheet.dart';
import 'package:opentranscribe/view/widgets/sheet_message.dart';

/// Asks before a re-transcription replaces a hand-edited transcript, the one
/// action that throws typed words away. Returns whether the user confirmed;
/// dismissing the sheet is the no. The run starts on the caller's side, AFTER
/// the sheet has closed, so its work lands on the screen and not under a modal.
Future<bool> showRetranscribeConfirmSheet(BuildContext context) async {
  final confirmed = await showAppSheet<bool>(
    context,
    builder: (context) => const _ConfirmContent(),
  );
  return confirmed ?? false;
}

class _ConfirmContent extends StatelessWidget {
  const _ConfirmContent();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SheetMessage(
      icon: AppIcons.pencil,
      title: l10n.retranscribeOverEditTitle,
      body: l10n.retranscribeOverEditBody,
      action: AppButton(label: l10n.retranscribe, onPressed: () => Navigator.of(context).pop(true)),
    );
  }
}
