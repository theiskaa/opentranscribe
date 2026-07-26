import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/utils/haptics.dart';
// LiquidToggle / PlatformCaps imports removed with the native branch above; add
// them back if that branch is ever revived for a non-blurred context.

/// The app's switch, adaptive like every other native control: the real iOS
/// glass switch on iOS 26 (via the vendored [LiquidToggle]), and the app's own
/// drawn switch everywhere else. Same 51x31 footprint and on-colour across the
/// split, so a settings row reads the same wherever it runs.
class AppToggle extends StatelessWidget {
  const AppToggle({required this.value, required this.onChanged, super.key});

  final bool value;
  final ValueChanged<bool>? onChanged;

  static const _width = 51.0;
  static const _height = 31.0;

  @override
  Widget build(BuildContext context) {
    // ALWAYS the drawn switch, even on iOS 26. The native glass toggle
    // ([LiquidToggle]) is a platform view, and Flutter's BackdropFilter cannot
    // blur a platform view - so under the settings screens' frosted bar it
    // punches straight through the blur and renders on top, which reads as
    // broken. Every toggle in the app lives under that bar, so the native path
    // is unreachable in practice; kept here, commented, for a future context
    // that has no blur over it.
    //
    // if (PlatformCaps.nativeGlass) {
    //   return SizedBox(
    //     width: _width,
    //     height: _height,
    //     child: LiquidToggle(
    //       initialValue: value,
    //       enabled: onChanged != null,
    //       accentColor: context.theme.settings.toggleActive,
    //       onChanged: onChanged,
    //     ),
    //   );
    // }
    return _DrawnToggle(value: value, onChanged: onChanged);
  }
}

/// A drawn iOS-style switch: 51x31 pill track, white knob, tap or drag. The knob
/// and track colour animate together so a drag reads as one object moving. The
/// fallback below iOS 26, where there is no native glass switch.
class _DrawnToggle extends StatefulWidget {
  const _DrawnToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  State<_DrawnToggle> createState() => _DrawnToggleState();
}

class _DrawnToggleState extends State<_DrawnToggle> with SingleTickerProviderStateMixin {
  static const _width = AppToggle._width;
  static const _height = AppToggle._height;
  static const _knob = 27.0;

  /// The knob's position, 0 (off) to 1 (on). Driven 1:1 by a drag, then settled
  /// with a velocity-seeded spring; the track colour reads the same value, so
  /// knob and track move as one object.
  late final AnimationController _pos = AnimationController.unbounded(
    vsync: this,
    value: widget.value ? 1 : 0,
  );

  /// True between our own commit and the resulting parent rebuild, so
  /// [didUpdateWidget] does not spring a second time over the one we just began.
  bool _selfCommit = false;
  bool _dragging = false;

  bool get _enabled => widget.onChanged != null;

  @override
  void didUpdateWidget(_DrawnToggle old) {
    super.didUpdateWidget(old);
    if (old.value == widget.value) return;
    // An outside flip (a settings load, a linked control): glide to it. Our own
    // commit already sprang with the release velocity - leave that momentum be.
    if (_selfCommit || _dragging) return;
    _spring(widget.value ? 1 : 0);
  }

  @override
  void dispose() {
    _pos.dispose();
    super.dispose();
  }

  void _spring(double target, {double velocity = 0}) {
    if (context.reduceMotion) {
      _pos.stop();
      _pos.value = target;
      return;
    }
    final spring = SpringSimulation(context.motionNow.toggleSpring, _pos.value, target, velocity);
    // Clamp to the ends so a hard fling cannot push the knob past the track.
    _pos.animateWith(ClampedSimulation(spring, xMin: 0, xMax: 1));
  }

  // Settle to [target], firing the change (and a haptic) when it flips the value.
  void _change(bool target, double fractionVelocity) {
    // Spring toward the predicted target at once, so the knob answers the release
    // immediately rather than waiting on the parent to echo the new value back.
    _spring(target ? 1 : 0, velocity: fractionVelocity);
    if (target == widget.value) return;
    Haptics.light();
    _selfCommit = true;
    widget.onChanged!(target);
    // widget.value is the source of truth. An accepted change lands via
    // didUpdateWidget (which leaves this momentum spring alone); a declined one
    // never fires it, so reconcile next frame - snap back to the real value.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _selfCommit = false;
      if (widget.value != target) _spring(widget.value ? 1 : 0);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    _dragging = false;
    final velocity = details.velocity.pixelsPerSecond.dx;
    final target = velocity.abs() > 200 ? velocity > 0 : _pos.value > 0.5;
    // px/s to fraction/s over the knob's travel, so the spring leaves at the
    // finger's speed.
    _change(target, velocity / (_width - _knob));
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Flip from where the knob ACTUALLY is, not widget.value: the latter only
      // reconciles a frame after a commit, so a fast double-tap read from it
      // would resolve both taps to the same target.
      onTap: _enabled ? () => _change(_pos.value <= 0.5, 0) : null,
      onHorizontalDragStart: _enabled
          ? (_) {
              _pos.stop();
              _dragging = true;
            }
          : null,
      onHorizontalDragUpdate: _enabled
          ? (details) =>
                _pos.value = (_pos.value + details.delta.dx / (_width - _knob)).clamp(0.0, 1.0)
          : null,
      onHorizontalDragEnd: _enabled ? _onDragEnd : null,
      child: Opacity(
        opacity: _enabled ? 1 : 0.5,
        child: AnimatedBuilder(
          animation: _pos,
          builder: (context, child) {
            final fraction = _pos.value;
            return Container(
              width: _width,
              height: _height,
              decoration: BoxDecoration(
                color: Color.lerp(theme.hairline, theme.settings.toggleActive, fraction)!,
                borderRadius: BorderRadius.circular(_height / 2),
              ),
              child: Align(
                alignment: Alignment.lerp(Alignment.centerLeft, Alignment.centerRight, fraction)!,
                child: child,
              ),
            );
          },
          child: Container(
            width: _knob,
            height: _knob,
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: theme.shadow.withValues(alpha: 0.12),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
