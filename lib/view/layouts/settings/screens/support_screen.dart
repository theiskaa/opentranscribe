import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:opentranscribe/core/app/deps.dart';
import 'package:opentranscribe/core/state/support_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/support/supporter_tier.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/app_icons.dart';
import 'package:opentranscribe/core/utils/url.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/layouts/settings/components/support_rows.dart';
import 'package:opentranscribe/view/widgets/app_scaffold.dart';
import 'package:opentranscribe/view/widgets/app_sheet.dart';
import 'package:opentranscribe/view/widgets/settings_kit.dart';
import 'package:opentranscribe/view/widgets/sheet_message.dart';

/// Support: the supporter purchase, restore, and manage surface. Owns a
/// [SupportCubit] so prices are fetched on every open; the cached tier
/// renders truthfully with or without the store.
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SupportCubit(service: Deps.i.supportService)..load(),
      child: const _SupportView(),
    );
  }
}

class _SupportView extends StatelessWidget {
  const _SupportView();

  Future<void> _buy(BuildContext context, String id) async {
    final result = await context.read<SupportCubit>().purchase(id);
    if (!context.mounted || result == null) return;
    if (result == SupportPurchaseResult.failed) unawaited(_failSheet(context));
  }

  Future<void> _restore(BuildContext context) async {
    final result = await context.read<SupportCubit>().restore();
    if (!context.mounted || result == null) return;
    switch (result) {
      case SupportRestoreResult.restored:
        break;
      case SupportRestoreResult.none:
        unawaited(_restoreNoneSheet(context));
      case SupportRestoreResult.failed:
        unawaited(_failSheet(context));
    }
  }

  Future<void> _failSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return showAppSheet<void>(
      context,
      builder: (context) => SheetMessage(
        icon: AppIcons.xmark,
        title: l10n.supportFailedTitle,
        body: l10n.supportFailedBody,
      ),
    );
  }

  Future<void> _restoreNoneSheet(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return showAppSheet<void>(
      context,
      builder: (context) => SheetMessage(
        icon: AppIcons.heart,
        title: l10n.supportRestoreNoneTitle,
        body: l10n.supportRestoreNoneBody,
      ),
    );
  }

  String _thanksOrPitch(AppLocalizations l10n, SupporterTier tier) => switch (tier) {
    SupporterTier.none => l10n.supportPitch,
    SupporterTier.monthly => l10n.supportThanksMonthly,
    SupporterTier.lifetime => l10n.supportThanksLifetime,
  };

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    final cubit = context.read<SupportCubit>();
    final state = context.watch<SupportCubit>().state;
    final rows = supportRowsFor(
      tier: state.tier,
      products: state.products,
      storeUnreachable: state.storeUnreachable,
    );
    final idle = !state.isBusy;
    return AppScaffold(
      background: theme.screens.settings,
      onBack: () => context.pop(),
      child: SettingsList(
        children: [
          const SizedBox(height: 10),
          SectionInfo(_thanksOrPitch(l10n, state.tier)),
          SettingsCard(
            children: [
              for (final row in rows)
                switch (row.kind) {
                  SupportRowKind.buyMonthly => SettingsBusyRow(
                    icon: AppIcons.heart,
                    label: l10n.supportMonthly,
                    detail: l10n.supportPerMonth(row.product!.displayPrice),
                    busy: state.purchasingId == row.product!.id,
                    onTap: idle ? () => unawaited(_buy(context, row.product!.id)) : null,
                  ),
                  SupportRowKind.buyLifetime => SettingsBusyRow(
                    icon: AppIcons.heartFill,
                    label: l10n.supportLifetime,
                    detail: l10n.supportOnce(row.product!.displayPrice),
                    busy: state.purchasingId == row.product!.id,
                    onTap: idle ? () => unawaited(_buy(context, row.product!.id)) : null,
                  ),
                  SupportRowKind.manage => SettingsBusyRow(
                    icon: AppIcons.gearshape,
                    label: l10n.supportManage,
                    busy: false,
                    onTap: idle ? () => unawaited(cubit.manageSubscriptions()) : null,
                  ),
                  SupportRowKind.restore => SettingsBusyRow(
                    icon: AppIcons.arrowCounterclockwise,
                    label: l10n.supportRestore,
                    busy: state.restoring,
                    onTap: idle ? () => unawaited(_restore(context)) : null,
                  ),
                },
            ],
          ),
          if (state.storeUnreachable) ...[
            const SizedBox(height: AppSpacing.md),
            SectionInfo(l10n.supportUnreachable),
          ],
          if (state.pendingApproval) ...[
            const SizedBox(height: AppSpacing.md),
            SectionInfo(l10n.supportPending),
          ],
          if (state.tier == SupporterTier.monthly &&
              rows.any((r) => r.kind == SupportRowKind.buyLifetime)) ...[
            const SizedBox(height: AppSpacing.md),
            SectionInfo(l10n.supportUpgradeInfo),
          ],
          const SizedBox(height: AppSpacing.md),
          SectionInfoLink(
            text: l10n.supportPrivacyInfo,
            linkLabel: l10n.supportPrivacy,
            icon: AppIcons.arrowUpRight,
            onTap: () => unawaited(openLink(kPrivacyUrl)),
          ),
          SectionInfoLink(
            text: l10n.supportTermsInfo,
            linkLabel: l10n.supportTerms,
            icon: AppIcons.arrowUpRight,
            onTap: () => unawaited(openLink(kTermsUrl)),
          ),
        ],
      ),
    );
  }
}
