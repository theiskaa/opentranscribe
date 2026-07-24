import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/utils/haptics.dart';

/// The shared press primitive: opacity dip (and optional scale) on touch, the
/// iOS feel with no ink. Rows, icon presses, and text buttons build on this so
/// every touch in the app answers the same way.
class Touchable extends StatefulWidget {
  const Touchable({
    required this.child,
    required this.onTap,
    this.pressedOpacity = 0.4,
    this.pressedScale,
    this.haptic = false,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double pressedOpacity;

  /// Optional scale-down target (e.g. 0.92 for icon buttons); null means
  /// opacity only.
  final double? pressedScale;
  final bool haptic;

  @override
  State<Touchable> createState() => _TouchableState();
}

class _TouchableState extends State<Touchable> {
  bool _pressed = false;

  bool get _enabled => widget.onTap != null;

  void _setPressed(bool pressed) {
    if (!_enabled || _pressed == pressed) return;
    setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    Widget child = AnimatedOpacity(
      opacity: _pressed ? widget.pressedOpacity : 1.0,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
      child: widget.child,
    );
    if (widget.pressedScale != null) {
      child = AnimatedScale(
        scale: _pressed ? widget.pressedScale! : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: child,
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        _setPressed(true);
        if (_enabled && widget.haptic) Haptics.light();
      },
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      onTap: widget.onTap,
      child: child,
    );
  }
}
