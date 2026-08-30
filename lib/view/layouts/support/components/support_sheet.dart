import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import 'package:opentranscribe/core/app/deps.dart';
import 'package:opentranscribe/core/routes/routes.dart';
import 'package:opentranscribe/core/state/support_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/app_motion.dart';
import 'package:opentranscribe/core/theming/app_theme_family.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/core/utils/url.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/app_button.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/app_sheet.dart';
import 'package:opentranscribe/view/widgets/app_spinner.dart';
import 'package:opentranscribe/view/widgets/club_lockup.dart';
import 'package:opentranscribe/view/widgets/dither_field.dart';
import 'package:opentranscribe/view/widgets/settings_kit.dart';
import 'package:opentranscribe/view/widgets/sheet_message.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';

/// The club as a sheet: one [SupportCubit] across both slots, so the price is
/// fetched once per open and the cached tier renders truthfully with or
/// without the store.
///
/// [blockedAction] is the tap the club stood in the way of (wearing a locked
/// theme). Joining runs it: the confirmation lands, the sheet leaves, and the
/// action follows. Without one the confirmation simply stays.
Future<void> showSupportSheet(BuildContext context, {VoidCallback? blockedAction}) async {
  if (_open) return;
  _open = true;
  try {
    final cubit = SupportCubit(service: Deps.i.supportService);
    unawaited(cubit.load());
    // At teardown, not at the pop: the panel is still on screen through its
    // exit, and a guard cleared early lets a second sheet open behind it.
    void gone() {
      _open = false;
      unawaited(cubit.close());
    }

    await showAppSheet<void>(
      context,
      inset: AppSpacing.md,
      tall: true,
      backdrop: const _ClubHalo(),
      footer: (context) => BlocProvider.value(
        value: cubit,
        child: _SupportBar(blockedAction: blockedAction, onGone: gone),
      ),
      builder: (context) => BlocProvider.value(value: cubit, child: const _SupportBody()),
    );
  } catch (_) {
    _open = false;
    rethrow;
  }
}

/// A second panel over the first reads as a rendering fault, and a double tap
/// on a locked card is easy: the club opens once at a time.
bool _open = false;

/// The scrolling half: who the club is, and what it unlocks.
class _SupportBody extends StatelessWidget {
  const _SupportBody();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SupportCubit>().state;
    return AnimatedSize(
      // A crossfade or a rise on the incoming face would read as the sheet
      // closing and reopening; only the height moves.
      duration: context.reduceMotion ? AppMotion.instant : context.theme.motion.expand,
      curve: context.theme.motion.indicatorCurve,
      alignment: Alignment.topCenter,
      child: state.tier.isSupporter ? const _MemberFace() : _PaywallFace(state: state),
    );
  }
}

/// The prospect's face. The join button lives in the sheet's footer, not here,
/// so a long pitch never buries it.
class _PaywallFace extends StatelessWidget {
  const _PaywallFace({required this.state});

  final SupportState state;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Lockup(),
        const SizedBox(height: AppSpacing.lg),
        SectionInfo(l10n.supportPitchFree),
        SectionInfo(l10n.supportPitch),
        if (state.storeUnreachable) SectionInfo(l10n.supportUnreachable),
        if (state.pendingApproval) SectionInfo(l10n.supportPending),
        const _PerksCard(),
        const SizedBox(height: AppSpacing.lg),
        const _FooterNote(),
      ],
    );
  }
}

/// The member's face: a confirmation, with nothing left to sell.
class _MemberFace extends StatelessWidget {
  const _MemberFace();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Lockup(member: true),
        const SizedBox(height: AppSpacing.lg),
        SectionInfo(l10n.supportThanks),
        const _PerksCard(),
      ],
    );
  }
}

/// The inset matches [SectionInfo]'s own, so the lockup and the lines below
/// share a left edge.
class _Lockup extends StatelessWidget {
  const _Lockup({this.member = false});

  final bool member;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: AppSpacing.sm),
    child: ClubLockup(member: member),
  );
}

/// The pinned strip: the join button over the quiet restore link (review
/// requires restore), or restore alone once the club is owned. Watches for the
/// tier landing, so a blocked action runs once the confirmation has read.
class _SupportBar extends StatefulWidget {
  const _SupportBar({required this.blockedAction, required this.onGone});

  final VoidCallback? blockedAction;

  /// Called when the panel is disposed, not when it is popped.
  final VoidCallback onGone;

  @override
  State<_SupportBar> createState() => _SupportBarState();
}

class _SupportBarState extends State<_SupportBar> {
  /// How long the confirmation holds before the sheet leaves to run the
  /// blocked action: enough for the swap to read as an answer, not a flicker.
  static const _confirmationHold = Duration(milliseconds: 550);

  bool _landed = false;
  ModalRoute<Object?>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  @override
  void dispose() {
    widget.onGone();
    super.dispose();
  }

  /// True while the club is the route in front. [State.mounted] is not enough:
  /// the panel stays mounted through its exit, and a message sheet can stand
  /// over it, so a blind pop would take the screen underneath instead.
  bool get _facing => mounted && (_route?.isCurrent ?? false);

  /// Closes the club itself, wherever it sits: popped when it is in front,
  /// lifted out when a message sheet stands over it.
  void _closeSheet() {
    final route = _route;
    if (route == null || !route.isActive) return;
    if (route.isCurrent) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).removeRoute(route);
    }
  }

  /// Joining finished what the reader started, whether they bought or restored.
  Future<void> _landBlockedAction() async {
    final action = widget.blockedAction;
    if (_landed || action == null) return;
    _landed = true;
    await Future<void>.delayed(_confirmationHold);
    if (!mounted) return;
    _closeSheet();
    action();
  }

  Future<void> _buy() async {
    final result = await context.read<SupportCubit>().purchase();
    if (!_facing || result == null) return;
    if (result == SupportPurchaseResult.failed) unawaited(_failSheet());
  }

  Future<void> _restore() async {
    final result = await context.read<SupportCubit>().restore();
    if (!_facing || result == null) return;
    switch (result) {
      case SupportRestoreResult.restored:
        break;
      case SupportRestoreResult.none:
        unawaited(_noneSheet());
      case SupportRestoreResult.failed:
        unawaited(_failSheet());
    }
  }

  Future<void> _failSheet() {
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

  Future<void> _noneSheet() {
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
    final l10n = AppLocalizations.of(context)!;
    final state = context.watch<SupportCubit>().state;
    final idle = !state.isBusy;
    final product = state.product;
    // An Ask to Buy wait hides the button too: a second purchase against the
    // pending transaction could only fail, and the waiting line explains.
    final selling =
        !state.tier.isSupporter &&
        !state.storeUnreachable &&
        !state.pendingApproval &&
        product != null;
    return BlocListener<SupportCubit, SupportState>(
      listenWhen: (previous, next) => !previous.tier.isSupporter && next.tier.isSupporter,
      listener: (_, _) => unawaited(_landBlockedAction()),
      // A price arriving late would otherwise pop the button in under the
      // panel's own height.
      child: AnimatedSize(
        duration: context.reduceMotion ? AppMotion.instant : context.theme.motion.expand,
        curve: context.theme.motion.indicatorCurve,
        alignment: Alignment.bottomCenter,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selling) ...[
              AppButton(
                label: l10n.supportJoin(product.displayPrice),
                icon: AppIcons.heartFill,
                isLoading: state.purchasing,
                onPressed: idle ? () => unawaited(_buy()) : null,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            _RestoreLink(
              onRestore: idle ? () => unawaited(_restore()) : null,
              restoring: state.restoring,
            ),
          ],
        ),
      ),
    );
  }
}

/// The club's brand halo: the website's top-right dither, riding the panel's
/// backdrop so it holds still while the pitch scrolls over it.
class _ClubHalo extends StatelessWidget {
  const _ClubHalo();

  /// Screen-relative, not panel-relative: the field reads the same however
  /// tall the sheet's content makes the panel.
  static const _widthFactor = 0.9;
  static const _heightFactor = 0.34;

  /// The reflection cards' ink, dimmed: the pitch sits over this field.
  static const _dim = 0.45;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final ink = context.theme.reflectionCard.dither;
    return Align(
      alignment: Alignment.topRight,
      child: SizedBox(
        width: size.width * _widthFactor,
        height: size.height * _heightFactor,
        child: DitherField(
          corner: DitherCorner.topRight,
          color: ink.withValues(alpha: ink.a * _dim),
        ),
      ),
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

/// The club's perks as a titled card, one label for both faces so the section
/// never re-words mid-purchase. Both perks live on the appearance screen, so a
/// row goes there, and a reader already on that screen just gets the sheet out
/// of the way.
class _PerksCard extends StatelessWidget {
  const _PerksCard();

  void _openAppearance(BuildContext context) {
    // A second tap arrives while the sheet is already leaving; popping again
    // would take the screen under it.
    if (!(ModalRoute.of(context)?.isCurrent ?? false)) return;
    final router = GoRouter.of(context);
    // The sheet is a dialog route outside the router's tree, so its own stack
    // is the only readable answer to where the reader already is.
    final onAppearance = router.routerDelegate.currentConfiguration.matches.any(
      (match) => match.matchedLocation == Routes.settingsAppearance,
    );
    Navigator.of(context).pop();
    if (!onAppearance) router.pushNamed(Routes.settingsAppearanceName);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(l10n.supportUnlocksSection),
        SettingsCard(
          children: [
            SettingsActionRow(
              leading: SvgPicture.asset(
                'assets/brand/wave.svg',
                width: 16,
                height: 16,
                theme: SvgTheme(currentColor: theme.text),
              ),
              label: l10n.supportPerkIcons,
              note: l10n.supportPerkIconsNote,
              onTap: () => _openAppearance(context),
            ),
            SettingsActionRow(
              leading: const _SwatchMark(),
              label: l10n.supportPerkThemes,
              note: l10n.supportPerkThemesNote,
              onTap: () => _openAppearance(context),
            ),
          ],
        ),
      ],
    );
  }
}

/// Three club accents fanned as one mark, so the themes perk previews the palettes.
class _SwatchMark extends StatelessWidget {
  const _SwatchMark();

  static const _families = [
    AppThemeFamily.gruvboxId,
    AppThemeFamily.draculaId,
    AppThemeFamily.nordId,
  ];
  static const _dot = 12.0;
  static const _step = 6.0;
  static const _ring = 1.5;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return SizedBox(
      width: _dot + _step * (_families.length - 1),
      height: _dot,
      child: Stack(
        children: [
          for (final (i, id) in _families.indexed)
            Positioned(
              left: _step * i,
              child: Container(
                width: _dot,
                height: _dot,
                decoration: BoxDecoration(
                  color: AppThemeFamily.byId(
                    id,
                  ).resolve(wantDark: theme.brightness == Brightness.dark).accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.surface, width: _ring),
                ),
              ),
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
