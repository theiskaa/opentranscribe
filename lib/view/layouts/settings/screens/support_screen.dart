import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:opentranscribe/core/app/deps.dart';
import 'package:opentranscribe/core/models/exporter_descriptor.dart';
import 'package:opentranscribe/core/state/support_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/support/supporter_tier.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/app_icons.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/core/utils/url.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/layouts/settings/components/support_rows.dart';
import 'package:opentranscribe/view/widgets/app_scaffold.dart';
import 'package:opentranscribe/view/widgets/app_sheet.dart';
import 'package:opentranscribe/view/widgets/export_format_row.dart';
import 'package:opentranscribe/view/widgets/settings_kit.dart';
import 'package:opentranscribe/view/widgets/sheet_message.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';
import 'package:opentranscribe/view/widgets/wave_glyph.dart';

/// Support: the supporter purchase, restore, and manage surface. Owns a
/// [SupportCubit] so prices are fetched on every open; the cached tier
/// renders truthfully with or without the store.
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SupportCubit(service: Deps.i.supportService)..load(),
      child: _SupportView(descriptors: Deps.i.exporterDescriptors),
    );
  }
}

class _SupportView extends StatelessWidget {
  const _SupportView({required this.descriptors});

  /// What supporting unlocks today: the shipped export formats, listed with
  /// the same marks and copy the Backup screen uses, so the promise and the
  /// feature always read identically.
  final List<ExporterDescriptor> descriptors;

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
          const SizedBox(height: AppSpacing.lg),
          _SupporterHeader(tag: l10n.supporterTag),
          const SizedBox(height: AppSpacing.lg),
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
          SectionLabel(l10n.supportUnlocksSection),
          SettingsCard(
            children: [
              for (final descriptor in descriptors)
                ExportFormatRow(descriptor: descriptor, selected: false, onTap: null),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const _FooterNote(),
        ],
      ),
    );
  }
}

/// The screen's identity: the app's wave over its name, tagged as the
/// supporter surface. The wave is [WaveGlyph], the same mark the empty home
/// draws, so the brand is drawn, never a bitmap.
class _SupporterHeader extends StatelessWidget {
  const _SupporterHeader({required this.tag});

  final String tag;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    // The small inset matches SectionInfo's own, so the lockup and the pitch
    // below share a left edge.
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.sm),
      child: Row(
        children: [
          WaveGlyph(color: theme.text),
          const SizedBox(width: AppSpacing.md),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('OpenTranscribe', style: AppType.title.copyWith(color: theme.text)),
              const SizedBox(height: AppSpacing.xs),
              Text(tag.toUpperCase(), style: AppType.eyebrow.copyWith(color: theme.accent)),
            ],
          ),
        ],
      ),
    );
  }
}

/// The compliance paragraph as one piece of prose: the privacy and terms
/// links ride inline as tappable accent spans instead of standing as their
/// own rows. The l10n template carries tokens where each label lands, so a
/// locale may order the two links however its sentence needs.
class _FooterNote extends StatelessWidget {
  const _FooterNote();

  static const _privacyToken = '\u0001';
  static const _termsToken = '\u0002';

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    final template = l10n.supportFooter(_privacyToken, _termsToken);
    final base = AppType.footnote.copyWith(color: theme.textSecondary, height: 1.5);
    final link = base.copyWith(color: theme.accent, fontWeight: FontWeight.w600);
    final spans = <InlineSpan>[];
    var start = 0;
    for (final match in RegExp('[$_privacyToken$_termsToken]').allMatches(template)) {
      if (match.start > start) {
        spans.add(TextSpan(text: template.substring(start, match.start)));
      }
      final privacy = template[match.start] == _privacyToken;
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: Touchable(
            onTap: () => unawaited(openLink(privacy ? kPrivacyUrl : kTermsUrl)),
            haptic: true,
            child: Text(privacy ? l10n.supportPrivacy : l10n.supportTerms, style: link),
          ),
        ),
      );
      start = match.end;
    }
    if (start < template.length) spans.add(TextSpan(text: template.substring(start)));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Text.rich(TextSpan(style: base, children: spans)),
    );
  }
}
