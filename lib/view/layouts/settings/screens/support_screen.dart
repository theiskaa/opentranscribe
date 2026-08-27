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
import 'package:opentranscribe/view/widgets/dither_field.dart';
import 'package:opentranscribe/view/widgets/export_format_row.dart';
import 'package:opentranscribe/view/widgets/settings_kit.dart';
import 'package:opentranscribe/view/widgets/sheet_message.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';

/// Support: the club purchase and restore surface. Owns a [SupportCubit] so
/// the price is fetched on every open; the cached tier renders truthfully
/// with or without the store. A prospect sees a single-offer paywall (pitch
/// above a pinned join button); a member sees a centered confirmation with
/// nothing left to sell.
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
    final state = context.watch<SupportCubit>().state;
    final idle = !state.isBusy;
    final member = state.tier.isSupporter;
    final onRestore = idle ? () => unawaited(_restore(context)) : null;
    final body = member
        ? _MemberBody(exportMark: exportMark, onRestore: onRestore, restoring: state.restoring)
        : _PaywallBody(
            exportMark: exportMark,
            state: state,
            onBuy: idle ? () => unawaited(_buy(context)) : null,
            onRestore: onRestore,
          );
    return AppScaffold(
      background: theme.screens.settings,
      onBack: () => context.pop(),
      child: Stack(children: [const _ClubDither(), body]),
    );
  }
}

/// The prospect's screen: the club pitch scrolling above the pinned join
/// button, with the perks framed as a promise and the compliance footer the
/// store requires before a purchase.
class _PaywallBody extends StatelessWidget {
  const _PaywallBody({
    required this.exportMark,
    required this.state,
    required this.onBuy,
    required this.onRestore,
  });

  final ExporterDescriptor exportMark;
  final SupportState state;
  final VoidCallback? onBuy;
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
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
              // The small inset matches SectionInfo's own, so the lockup and
              // the pitch below share a left edge.
              const Padding(
                padding: EdgeInsets.only(left: AppSpacing.sm),
                child: ClubLockup(),
              ),
              const SizedBox(height: AppSpacing.lg),
              SectionInfo(l10n.supportPitch),
              if (state.storeUnreachable) ...[
                const SizedBox(height: AppSpacing.xs),
                SectionInfo(l10n.supportUnreachable),
              ],
              if (state.pendingApproval) ...[
                const SizedBox(height: AppSpacing.xs),
                SectionInfo(l10n.supportPending),
              ],
              _PerksCard(exportMark: exportMark, member: false, checked: false),
              const SizedBox(height: AppSpacing.xl),
              const _FooterNote(),
            ],
          ),
        ),
        _PurchaseBar(state: state, onBuy: onBuy, onRestore: onRestore),
      ],
    );
  }
}

/// The member's screen: a centered confirmation. The lockup wears its heart,
/// the thanks stands in for the pitch, and the perks read as owned. No button,
/// no compliance footer, nothing to pin, so the space reads as settled rather
/// than as a paywall with the button cut out. Restore stays, quietly, as the
/// recovery path.
///
/// The perks arrive unchecked and tick over on the first frame, so their
/// checkmarks pop in instead of landing already ticked. Under Reduce Motion the
/// flip is a single frame with no crossfade, so it reads as an instant tick.
class _MemberBody extends StatefulWidget {
  const _MemberBody({required this.exportMark, required this.onRestore, required this.restoring});

  final ExporterDescriptor exportMark;
  final VoidCallback? onRestore;
  final bool restoring;

  @override
  State<_MemberBody> createState() => _MemberBodyState();
}

class _MemberBodyState extends State<_MemberBody> {
  bool _owned = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _owned = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        Expanded(
          // Center when the confirmation fits, scroll when a small screen or
          // large type would otherwise clip it. A bare Center over the scroll
          // view would top-align, since the scroll view fills the height.
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppScaffold.topPaddingOf(context),
              ),
              child: ConstrainedBox(
                // Clamped at zero: nothing guarantees the viewport clears twice
                // the top inset, and a negative minHeight is a hard assert.
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - AppScaffold.topPaddingOf(context) * 2).clamp(
                    0.0,
                    double.infinity,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: AppSpacing.sm),
                      child: ClubLockup(member: true),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SectionInfo(l10n.supportThanks),
                    const SizedBox(height: AppSpacing.xl),
                    _PerksCard(exportMark: widget.exportMark, member: true, checked: _owned),
                  ],
                ),
              ),
            ),
          ),
        ),
        _RestoreBar(onRestore: widget.onRestore, restoring: widget.restoring),
      ],
    );
  }
}

/// The club's brand halo: the website's top-right dither drawn in-app, behind
/// both bodies and always on, so the screen wears the same face the landing
/// page does. Borrows the reflection family's dither ink, the one place the
/// tint is defined.
class _ClubDither extends StatelessWidget {
  const _ClubDither();

  /// The corner patch as a fraction of the screen, wide and tall enough for the
  /// glow to breathe past the top bar before it dies toward the content.
  static const _widthFactor = 0.82;
  static const _heightFactor = 0.46;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Positioned(
      top: 0,
      right: 0,
      width: size.width * _widthFactor,
      height: size.height * _heightFactor,
      child: IgnorePointer(
        child: DitherField(
          corner: DitherCorner.topRight,
          color: context.theme.reflectionCard.dither,
        ),
      ),
    );
  }
}

/// The prospect's pinned strip: the join button above the quiet restore link
/// (review requires restore, and it is every user's recovery path). An
/// unreachable or pending store has nothing to sell, so only the link remains.
class _PurchaseBar extends StatelessWidget {
  const _PurchaseBar({required this.state, required this.onBuy, required this.onRestore});

  final SupportState state;
  final VoidCallback? onBuy;
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final product = state.product;
    // An Ask to Buy wait hides the button too: a second purchase against the
    // pending transaction could only fail, and the waiting line explains.
    final selling = !state.storeUnreachable && !state.pendingApproval && product != null;
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
          _RestoreLink(onRestore: onRestore, restoring: state.restoring),
        ],
      ),
    );
  }
}

/// The member's bottom strip: only the quiet restore link, held off the safe
/// area the same way the prospect's bar is, so the recovery path sits where a
/// returning member expects it without dressing the screen as a paywall.
class _RestoreBar extends StatelessWidget {
  const _RestoreBar({required this.onRestore, required this.restoring});

  final VoidCallback? onRestore;
  final bool restoring;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        MediaQuery.paddingOf(context).bottom + AppSpacing.sm,
      ),
      child: _RestoreLink(onRestore: onRestore, restoring: restoring),
    );
  }
}

/// The restore action as a quiet centered link. The Touchable hugs the label
/// inside a stable seat, so the spinner swap never shifts it and a full-width
/// strip never fires restore on a stray tap.
class _RestoreLink extends StatelessWidget {
  const _RestoreLink({required this.onRestore, required this.restoring});

  final VoidCallback? onRestore;
  final bool restoring;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      height: 20,
      child: Center(
        child: Touchable(
          onTap: onRestore,
          haptic: onRestore != null,
          child: AnimatedSwitcher(
            duration: context.reduceMotion ? Duration.zero : theme.motion.crossfade,
            child: restoring
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
    );
  }
}

/// The club's perks as a titled card. [member] frames the section (a member's
/// "What you get" versus a prospect's "Club members get") and is stable across
/// the confirmation's entrance; [checked] drives the row checkmarks alone, so a
/// member's perks can tick over after the screen has settled without the label
/// flickering.
class _PerksCard extends StatelessWidget {
  const _PerksCard({required this.exportMark, required this.member, required this.checked});

  final ExporterDescriptor exportMark;
  final bool member;
  final bool checked;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(member ? l10n.supportMemberUnlocks : l10n.supportUnlocksSection),
        SettingsCard(
          children: [
            _PerkRow(
              leading: ExporterLogo(exportMark),
              label: l10n.supportPerkExports,
              note: l10n.supportPerkExportsNote,
              owned: checked,
            ),
            _PerkRow(
              leading: AppIcon(AppIcons.sparkles, size: 16, color: theme.text),
              label: l10n.supportPerkFuture,
              note: l10n.supportPerkFutureNote,
              owned: checked,
            ),
          ],
        ),
      ],
    );
  }
}

/// One thing the club gets, said as a benefit: a mark in the settings tile,
/// a plain name, and a one-line note. Inert on purpose; the join button is
/// the only action this screen sells.
class _PerkRow extends StatelessWidget {
  const _PerkRow({
    required this.leading,
    required this.label,
    required this.note,
    required this.owned,
  });

  final Widget leading;
  final String label;
  final String note;

  /// A member owns the perk, so the row inks and takes a check; a non-member's
  /// row stays quiet, a promise rather than a possession.
  final bool owned;

  @override
  Widget build(BuildContext context) {
    return SelectableRow(label: label, note: note, leading: leading, selected: owned, onTap: null);
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
