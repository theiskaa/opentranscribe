import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:opentranscribe/core/app/deps.dart';
import 'package:opentranscribe/core/models/exporter_descriptor.dart';
import 'package:opentranscribe/core/state/support_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/core/utils/url.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/app_button.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/app_scaffold.dart';
import 'package:opentranscribe/view/widgets/app_sheet.dart';
import 'package:opentranscribe/view/widgets/app_spinner.dart';
import 'package:opentranscribe/view/widgets/club_lockup.dart';
import 'package:opentranscribe/view/widgets/export_format_row.dart';
import 'package:opentranscribe/view/widgets/settings_kit.dart';
import 'package:opentranscribe/view/widgets/sheet_message.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';

/// Support: the club purchase and restore surface. Owns a [SupportCubit] so
/// the price is fetched on every open; the cached tier renders truthfully
/// with or without the store. The one purchase action is pinned to the
/// bottom, the way a single-offer paywall should read; everything above it
/// scrolls.
class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final descriptors = Deps.i.exporterDescriptors;
    return BlocProvider(
      create: (_) => SupportCubit(service: Deps.i.supportService)..load(),
      child: _SupportView(
        exportMark:
            descriptors.where((d) => d.format == ExportFormat.markdown).firstOrNull ??
            descriptors.first,
      ),
    );
  }
}

class _SupportView extends StatelessWidget {
  const _SupportView({required this.exportMark});

  /// The format whose mark fronts the exports perk (markdown, with the first
  /// shipped format standing in if a build ever drops it): the same asset the
  /// Backup screen picks from, so the promise and the feature wear one face.
  final ExporterDescriptor exportMark;

  Future<void> _buy(BuildContext context) async {
    final result = await context.read<SupportCubit>().purchase();
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

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    final state = context.watch<SupportCubit>().state;
    final idle = !state.isBusy;
    return AppScaffold(
      background: theme.screens.settings,
      onBack: () => context.pop(),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              // SettingsList's insets minus the bottom safe area, which the
              // pinned bar below owns.
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppScaffold.topPaddingOf(context) - AppSpacing.md,
                AppSpacing.md,
                AppSpacing.lg,
              ),
              children: [
                const SizedBox(height: AppSpacing.lg),
                // The small inset matches SectionInfo's own, so the lockup
                // and the pitch below share a left edge.
                const Padding(
                  padding: EdgeInsets.only(left: AppSpacing.sm),
                  child: ClubLockup(),
                ),
                const SizedBox(height: AppSpacing.lg),
                SectionInfo(state.tier.isSupporter ? l10n.supportThanks : l10n.supportPitch),
                if (state.storeUnreachable && !state.tier.isSupporter) ...[
                  const SizedBox(height: AppSpacing.xs),
                  SectionInfo(l10n.supportUnreachable),
                ],
                if (state.pendingApproval) ...[
                  const SizedBox(height: AppSpacing.xs),
                  SectionInfo(l10n.supportPending),
                ],
                SectionLabel(l10n.supportUnlocksSection),
                SettingsCard(
                  children: [
                    _PerkRow(
                      leading: ExporterLogo(exportMark),
                      label: l10n.supportPerkExports,
                      note: l10n.supportPerkExportsNote,
                    ),
                    _PerkRow(
                      leading: AppIcon(AppIcons.sparkles, size: 16, color: theme.text),
                      label: l10n.supportPerkFuture,
                      note: l10n.supportPerkFutureNote,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                const _FooterNote(),
              ],
            ),
          ),
          _PurchaseBar(
            state: state,
            onBuy: idle ? () => unawaited(_buy(context)) : null,
            onRestore: idle ? () => unawaited(_restore(context)) : null,
          ),
        ],
      ),
    );
  }
}

/// The pinned commerce strip: the one join button, price in its label, and
/// the quiet restore link every state keeps (review requires it, and it is
/// every user's recovery path). A member or an unreachable store has nothing
/// to sell, so only the link remains.
class _PurchaseBar extends StatelessWidget {
  const _PurchaseBar({required this.state, required this.onBuy, required this.onRestore});

  final SupportState state;
  final VoidCallback? onBuy;
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    final product = state.product;
    // An Ask to Buy wait hides the button too: a second purchase against the
    // pending transaction could only fail, and the waiting line explains.
    final selling =
        !state.tier.isSupporter &&
        !state.storeUnreachable &&
        !state.pendingApproval &&
        product != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        MediaQuery.paddingOf(context).bottom + AppSpacing.sm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selling) ...[
            AppButton(
              label: l10n.supportJoin(product.displayPrice),
              icon: AppIcons.heartFill,
              isLoading: state.purchasing,
              onPressed: onBuy,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          SizedBox(
            // A stable seat, so the spinner swap never shifts the button. The
            // Touchable hugs the label inside it: restore walks the tier to
            // whatever the store answers, so a full-width strip must not fire
            // it on a stray tap.
            height: 20,
            child: Center(
              child: Touchable(
                onTap: onRestore,
                haptic: onRestore != null,
                child: AnimatedSwitcher(
                  duration: context.reduceMotion ? Duration.zero : theme.motion.crossfade,
                  child: state.restoring
                      ? AppSpinner(size: 14, color: theme.textSecondary)
                      : Text(
                          l10n.supportRestore,
                          key: const ValueKey('restore'),
                          style: AppType.footnote.copyWith(
                            color: theme.accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One thing the club gets, said as a benefit: a mark in the settings tile,
/// a plain name, and a one-line note. Inert on purpose; the join button is
/// the only action this screen sells.
class _PerkRow extends StatelessWidget {
  const _PerkRow({required this.leading, required this.label, required this.note});

  final Widget leading;
  final String label;
  final String note;

  @override
  Widget build(BuildContext context) {
    return SelectableRow(label: label, note: note, leading: leading, selected: false, onTap: null);
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
