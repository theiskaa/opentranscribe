import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/utils/duo_layout.dart';
import 'package:opentranscribe/view/widgets/duo_style.dart';

class DuoDetailSwap extends StatefulWidget {
  const DuoDetailSwap({
    required this.child,
    required this.entryId,
    required this.location,
    super.key,
  });

  final Widget child;
  final String entryId;
  final Uri location;

  @override
  State<DuoDetailSwap> createState() => _DuoDetailSwapState();
}

class _DuoDetailSwapState extends State<DuoDetailSwap> {
  String? _entryId;
  Uri? _location;
  Object? _identity;

  @override
  Widget build(BuildContext context) {
    final motion = context.theme.motion;
    final inner = duoInnerOf(context);
    final reduce = context.reduceMotion;
    _identity = duoDetailIdentity(
      inner: inner,
      entryId: widget.entryId,
      location: widget.location,
      previousEntryId: _entryId,
      previousLocation: _location,
      previousIdentity: _identity,
    );
    _entryId = widget.entryId;
    _location = widget.location;
    return DuoDetailSelection(
      entryId: widget.entryId,
      child: AnimatedSwitcher(
        duration: !inner
            ? Duration.zero
            : reduce
            ? motion.duoDetailReduced
            : motion.duoDetailEnter,
        reverseDuration: !inner
            ? Duration.zero
            : reduce
            ? motion.duoDetailReduced
            : motion.duoDetailFade,
        layoutBuilder: (current, previous) => Stack(
          fit: StackFit.expand,
          children: [
            for (final child in previous) IgnorePointer(child: ExcludeSemantics(child: child)),
            ?current,
          ],
        ),
        transitionBuilder: (child, animation) =>
            _DuoDetailTransition(animation: animation, child: child),
        child: KeyedSubtree(key: ValueKey(_identity), child: widget.child),
      ),
    );
  }
}

class _DuoDetailTransition extends StatelessWidget {
  const _DuoDetailTransition({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final inner = duoInnerOf(context);
    final reduce = context.reduceMotion;
    final motion = context.theme.motion;
    return _DuoDetailAnimation(
      animation: animation,
      child: AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, child) => Opacity(
          opacity: inner
              ? duoDetailVisual(
                  progress: animation.value,
                  incoming: animation.status != AnimationStatus.reverse,
                  reduce: reduce,
                  motion: motion,
                ).opacity
              : 1,
          child: child,
        ),
      ),
    );
  }
}

class _DuoDetailAnimation extends InheritedWidget {
  const _DuoDetailAnimation({required this.animation, required super.child});

  final Animation<double> animation;

  @override
  bool updateShouldNotify(_DuoDetailAnimation oldWidget) => animation != oldWidget.animation;
}

class DuoDetailRise extends StatelessWidget {
  const DuoDetailRise({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final animation =
        context.dependOnInheritedWidgetOfExactType<_DuoDetailAnimation>()?.animation ??
        const AlwaysStoppedAnimation(1.0);
    final inner = duoInnerOf(context);
    final reduce = context.reduceMotion;
    final motion = context.theme.motion;
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) => Transform.translate(
        offset: Offset(
          0,
          inner
              ? duoDetailVisual(
                  progress: animation.value,
                  incoming: animation.status != AnimationStatus.reverse,
                  reduce: reduce,
                  motion: motion,
                ).rise
              : 0,
        ),
        child: child,
      ),
    );
  }
}

class DuoDetailSelection extends InheritedWidget {
  const DuoDetailSelection({required this.entryId, required super.child, super.key});

  final String entryId;

  static bool isActive(BuildContext context, String entryId) {
    final selected = context.dependOnInheritedWidgetOfExactType<DuoDetailSelection>()?.entryId;
    return selected == null || selected == entryId;
  }

  @override
  bool updateShouldNotify(DuoDetailSelection oldWidget) => entryId != oldWidget.entryId;
}
