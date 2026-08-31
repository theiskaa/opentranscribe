import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/wave_glyph.dart';

/// The club's identity lockup: the app's wave beside its name over the CLUB
/// eyebrow. One widget for every surface that fronts the club, so the brand
/// is drawn once and cannot drift. The wave is [WaveGlyph], the same mark the
/// empty home draws, never a bitmap. A [member] lockup wears a filled heart
/// beside the eyebrow, which beats in the first time it is shown.
class ClubLockup extends StatelessWidget {
  const ClubLockup({this.member = false, super.key});

  final bool member;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final tag = AppLocalizations.of(context)!.supporterTag;
    return Row(
      children: [
        WaveGlyph(color: theme.text),
        const SizedBox(width: AppSpacing.md),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('OpenTranscribe', style: AppType.title.copyWith(color: theme.text)),
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Text(tag.toUpperCase(), style: AppType.eyebrow.copyWith(color: theme.accent)),
                if (member) const _MemberHeart(),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/// The membership mark: a small filled heart that springs in the first time
/// the lockup is a member's, so the moment of joining lands. Still under
/// Reduce Motion.
class _MemberHeart extends StatelessWidget {
  const _MemberHeart();

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final heart = Padding(
      padding: const EdgeInsets.only(left: AppSpacing.sm),
      child: AppIcon(AppIcons.heartFill, size: 11, color: theme.accent),
    );
    if (context.reduceMotion) return heart;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: theme.motion.entrance,
      curve: theme.motion.swipePopCurve,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0, 1),
        child: Transform.scale(scale: t, child: child),
      ),
      child: heart,
    );
  }
}
