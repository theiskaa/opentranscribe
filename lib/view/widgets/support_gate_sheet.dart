import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:opentranscribe/core/routes/routes.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/app_button.dart';
import 'package:opentranscribe/view/widgets/app_sheet.dart';
import 'package:opentranscribe/view/widgets/club_lockup.dart';

/// The one sheet every supporter-gated surface answers with: the club's own
/// lockup as the header, so the gate previews the surface its action opens,
/// one line saying what is gated and what stays free, and the single action.
Future<void> showSupportGateSheet(BuildContext context) => showAppSheet<void>(
  context,
  builder: (context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ClubLockup(),
        const SizedBox(height: AppSpacing.lg),
        Text(
          l10n.supportGateBody,
          style: AppType.subhead.copyWith(color: theme.textSecondary, height: 1.5),
        ),
        const SizedBox(height: AppSpacing.xxl),
        AppButton(
          label: l10n.supportGateAction,
          onPressed: () {
            final router = GoRouter.of(context);
            Navigator.of(context).pop();
            router.pushNamed(Routes.settingsSupportName);
          },
        ),
      ],
    );
  },
);
