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

class _DrawnToggleState extends State<_DrawnToggle> {
  static const _width = AppToggle._width;
  static const _height = AppToggle._height;
  static const _knob = 27.0;

  /// 0..1 while a finger drives the knob; null when settled on [widget.value].
  double? _dragFraction;

  double get _fraction => _dragFraction ?? (widget.value ? 1 : 0);

  bool get _enabled => widget.onChanged != null;

  void _commit(bool value) {
    setState(() => _dragFraction = null);
    if (value != widget.value) {
      Haptics.light();
      widget.onChanged!(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final trackColor = Color.lerp(theme.hairline, theme.settings.toggleActive, _fraction)!;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _enabled ? () => _commit(!widget.value) : null,
      onHorizontalDragUpdate: _enabled
          ? (details) => setState(() {
              _dragFraction = (_fraction + details.delta.dx / (_width - _knob)).clamp(0.0, 1.0);
            })
          : null,
      onHorizontalDragEnd: _enabled
          ? (details) {
              final velocity = details.velocity.pixelsPerSecond.dx;
              final target = velocity.abs() > 200 ? velocity > 0 : _fraction > 0.5;
              _commit(target);
            }
          : null,
      child: Opacity(
        opacity: _enabled ? 1 : 0.5,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          width: _width,
          height: _height,
          decoration: BoxDecoration(
            color: trackColor,
            borderRadius: BorderRadius.circular(_height / 2),
          ),
          child: AnimatedAlign(
            duration: _dragFraction == null ? const Duration(milliseconds: 200) : Duration.zero,
            curve: Curves.easeOut,
            alignment: Alignment.lerp(Alignment.centerLeft, Alignment.centerRight, _fraction)!,
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
