import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';
import 'package:liquid/liquid.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/utils/haptics.dart';
import 'package:opentranscribe/core/utils/platform_caps.dart';

/// The app's switch, adaptive like every other native control: the real iOS
/// glass switch on iOS 26 (via the vendored [LiquidToggle]) at the system's
/// own footprint, and the app's drawn 51x31 switch everywhere else, same
/// on-colour across the split.
class AppToggle extends StatelessWidget {
  const AppToggle({required this.value, required this.onChanged, this.semanticLabel, super.key});

  final bool value;
  final ValueChanged<bool>? onChanged;

  /// What VoiceOver calls the switch, on both faces: the row's own label.
  final String? semanticLabel;

  /// The native box: the iOS 26 UISwitch's intrinsic width (its host centers
  /// the 61x28 switch and never lets it overflow) by the drawn switch's
  /// height, so the drawn stand-in fits the same box unsquashed.
  static const _nativeWidth = 61.0;
  static const _nativeHeight = 31.0;

  @override
  Widget build(BuildContext context) {
    final drawn = _DrawnToggle(value: value, onChanged: onChanged, semanticLabel: semanticLabel);
    if (!PlatformCaps.nativeGlass) return drawn;

    final theme = context.theme;
    // No haptic around onChanged: UISwitch plays its own on flip, and a
    // second one here would double it.
    return SizedBox(
      width: _nativeWidth,
      height: _nativeHeight,
      child: LiquidToggle(
        value: value,
        enabled: onChanged != null,
        accentColor: theme.settings.toggleActive,
        semanticLabel: semanticLabel,
        isDark: theme.brightness == Brightness.dark,
        onChanged: onChanged,
        placeholderBuilder: (_) => Center(child: drawn),
      ),
    );
  }
}

/// A drawn iOS-style switch: 51x31 pill track, white knob, tap or drag. The knob
/// and track colour animate together so a drag reads as one object moving. The
/// fallback below iOS 26, and the stand-in while a route covers the native
/// switch.
class _DrawnToggle extends StatefulWidget {
  const _DrawnToggle({required this.value, required this.onChanged, required this.semanticLabel});

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? semanticLabel;

  @override
  State<_DrawnToggle> createState() => _DrawnToggleState();
}

class _DrawnToggleState extends State<_DrawnToggle> with SingleTickerProviderStateMixin {
  static const _width = 51.0;
  static const _height = 31.0;
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

  // Guarded: the drag recognizer also cancels on a plain tap, whose spring
  // must not be undone.
  void _onDragCancel() {
    if (!_dragging) return;
    _dragging = false;
    _spring(widget.value ? 1 : 0);
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

    return Semantics(
      toggled: widget.value,
      enabled: _enabled,
      label: widget.semanticLabel,
      onTap: _enabled ? () => _change(!widget.value, 0) : null,
      excludeSemantics: true,
      child: GestureDetector(
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
        onHorizontalDragCancel: _enabled ? _onDragCancel : null,
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
      ),
    );
  }
}
