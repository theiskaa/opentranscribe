import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/app_button.dart';
import 'package:opentranscribe/view/widgets/dither.dart';
import 'package:opentranscribe/view/widgets/dither_card.dart';

/// The disabled card's slot: it materializes and decomposes through the
/// ordered-dither ladder ([DitherReveal]) when the menu toggle flips, and
/// only THEN does the height collapse - dissolve first, glide second, two
/// motions telling one story. A page mounted with reflections already off
/// shows the card settled: paging past it must not replay the arrival.
class ReflectionsDisabledSlot extends StatefulWidget {
  const ReflectionsDisabledSlot({required this.disabled, required this.onEnable, super.key});

  final bool disabled;

  /// The notice card's button: reenables in place (the card then dissolves).
  final VoidCallback onEnable;

  @override
  State<ReflectionsDisabledSlot> createState() => _ReflectionsDisabledSlotState();
}

class _ReflectionsDisabledSlotState extends State<ReflectionsDisabledSlot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    value: widget.disabled ? 1 : 0,
  );

  /// The eased clock the wave runs on: the frontier accelerates in and
  /// settles out instead of marching at one speed.
  late final CurvedAnimation _wave = CurvedAnimation(parent: _reveal, curve: Curves.easeInOut);

  /// The card stays in the tree through its dissolve; only a completed
  /// reverse removes it (an interrupted reverse's future never fires).
  late bool _present = widget.disabled;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reveal.duration = context.motionNow.ditherReveal;
  }

  @override
  void didUpdateWidget(ReflectionsDisabledSlot old) {
    super.didUpdateWidget(old);
    if (old.disabled == widget.disabled) return;
    if (widget.disabled) {
      setState(() => _present = true);
      if (context.reduceMotion) {
        _reveal.value = 1;
        return;
      }
      _reveal.forward();
      return;
    }
    if (context.reduceMotion) {
      _reveal.value = 0;
      setState(() => _present = false);
      return;
    }
    _reveal.reverse().whenComplete(() {
      if (!mounted || widget.disabled) return;
      setState(() => _present = false);
    });
  }

  @override
  void dispose() {
    _wave.dispose();
    _reveal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return ClipRect(
      child: AnimatedSize(
        duration: context.reduceMotion ? Duration.zero : theme.motion.indicator,
        curve: theme.motion.indicatorCurve,
        alignment: Alignment.topCenter,
        child: !_present
            ? const SizedBox(width: double.infinity)
            : Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: AnimatedBuilder(
                  animation: _wave,
                  builder: (context, child) => IgnorePointer(
                    ignoring: _wave.value < 1,
                    child: DitherReveal(
                      progress: _wave.value,
                      cover: theme.screens.settings,
                      child: child!,
                    ),
                  ),
                  child: _DisabledCard(onEnable: widget.onEnable),
                ),
              ),
      ),
    );
  }
}

/// The standing notice when reflections are switched off: a card in the
/// reflection family's own vocabulary - their ground and border, the corner
/// breath of dither, plain text - asleep, not broken. It says the open week
/// will go unwritten, and carries the way back: one button that reenables
/// in place. Static card matter, unlike the transient notice line beneath it.
class _DisabledCard extends StatelessWidget {
  const _DisabledCard({required this.onEnable});

  final VoidCallback onEnable;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    return DitherCard(
      patch: const Size(120, 72),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.reflectionsDisabledTitle, style: AppType.subhead.copyWith(color: theme.text)),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              l10n.reflectionsDisabledBody,
              style: AppType.footnote.copyWith(color: theme.textSecondary, height: 1.4),
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: l10n.reflectionsDisabledEnable,
              expand: false,
              height: theme.button.compactHeight,
              onPressed: onEnable,
            ),
          ],
        ),
      ),
    );
  }
}
