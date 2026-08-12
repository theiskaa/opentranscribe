import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:opentranscribe/core/routes/routes.dart';
import 'package:opentranscribe/core/theming/app_icons.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/app_button.dart';
import 'package:opentranscribe/view/widgets/app_sheet.dart';
import 'package:opentranscribe/view/widgets/sheet_message.dart';

/// The one sheet every supporter-gated surface answers with: the pitch and
/// the single action that opens the support screen.
Future<void> showSupportGateSheet(BuildContext context) => showAppSheet<void>(
  context,
  builder: (context) {
    final l10n = AppLocalizations.of(context)!;
    return SheetMessage(
      icon: AppIcons.lock,
      title: l10n.supportGateTitle,
      body: l10n.supportGateBody,
      action: AppButton(
        label: l10n.supportGateAction,
        onPressed: () {
          final router = GoRouter.of(context);
          Navigator.of(context).pop();
          router.pushNamed(Routes.settingsSupportName);
        },
      ),
    );
  },
);
