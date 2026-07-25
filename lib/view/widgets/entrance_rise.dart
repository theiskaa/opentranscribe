import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';

/// The one sanctioned entrance: fade plus a small rise, once, then stillness.
/// Siblings stagger via [delay]. Skips entirely when the platform asks for
/// reduced motion.
class EntranceRise extends StatefulWidget {
  const EntranceRise({required this.child, this.delay = Duration.zero, super.key});

  final Widget child;
  final Duration delay;

  @override
  State<EntranceRise> createState() => _EntranceRiseState();
}

class _EntranceRiseState extends State<EntranceRise> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final double _rise;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    final motion = context.motionNow;
    _rise = motion.entranceRise;
    _controller = AnimationController(vsync: this, duration: motion.entrance);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (context.reduceMotion) {
      _controller.value = 1;
    } else if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final motion = context.theme.motion;
    final curved = CurvedAnimation(parent: _controller, curve: motion.entranceCurve);
    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) => Opacity(
        opacity: curved.value,
        child: Transform.translate(offset: Offset(0, (1 - curved.value) * _rise), child: child),
      ),
      child: widget.child,
    );
  }
}
