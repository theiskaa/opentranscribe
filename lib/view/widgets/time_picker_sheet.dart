import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/superellipse.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/core/utils/haptics.dart';

/// A time of day as whole hours and minutes.
typedef TimeOfDayValue = ({int hour, int minute});

/// The app's time picker: two curved digit wheels (hours 00-23, minutes 00-59)
/// in the house tabular figures, over an ink selection pill that hugs the
/// wheels. Built on [ListWheelScrollView] (the widget CupertinoPicker itself
/// wraps) for the rounded barrel look and its FixedExtent scroll-and-snap, but
/// styled in our ink instead of the OS overlay. Presented in a dedicated sheet
/// so the wheels own the vertical gesture and the snap has nothing to fight. A
/// tap outside commits the current wheels; returns the chosen time, or null
/// only if popped without a selection (e.g. the system back gesture).
Future<TimeOfDayValue?> showTimePickerSheet(
  BuildContext context, {
  required int hour,
  required int minute,
}) {
  final barrier = context.themeNow.barrier;
  final reduce = context.reduceMotion;
  return showGeneralDialog<TimeOfDayValue>(
    context: context,
    // Not barrier-dismissible (the default): the sheet's own barrier handles a
    // tap-outside so it commits the current time instead of returning null.
    barrierLabel: '',
    barrierColor: barrier,
    transitionDuration: context.motionNow.sheetScrim,
    pageBuilder: (_, _, _) => _TimeWheelSheet(hour: hour, minute: minute),
    transitionBuilder: (context, animation, _, child) {
      if (reduce) return FadeTransition(opacity: animation, child: child);
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _TimeWheelSheet extends StatefulWidget {
  const _TimeWheelSheet({required this.hour, required this.minute});

  final int hour;
  final int minute;

  @override
  State<_TimeWheelSheet> createState() => _TimeWheelSheetState();
}

class _TimeWheelSheetState extends State<_TimeWheelSheet> {
  static const _extent = 42.0;
  static const _height = 210.0;
  static const _digitSize = 26.0;
  // The selection pill hugs the two wheels rather than spanning the sheet: a
  // full-width band left bare margins on the phone's wider sheet.
  static const _bandWidth = 240.0;

  late int _hour = widget.hour.clamp(0, 23);
  late int _minute = widget.minute.clamp(0, 59);

  // A tap-outside commits and pops. The route's reverse transition keeps the
  // barrier hit-testable for a beat after, so a second tap would fall through
  // and pop the screen beneath; this one-shot latch swallows it.
  bool _committed = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final sheet = theme.sheet;
    final digits = AppType.digits(AppType.title).copyWith(color: theme.text, fontSize: _digitSize);
    final radius = BorderRadius.vertical(top: Radius.circular(sheet.radius));

    return Stack(
      children: [
        // The dismiss barrier: a tap outside the sheet commits the current time
        // and closes. There is no separate confirm.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (_committed) return;
              _committed = true;
              Navigator.of(context).pop((hour: _hour, minute: _minute));
            },
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          // Absorb taps on the sheet so they never reach the barrier above.
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {},
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(color: sheet.background, borderRadius: radius),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.xl,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: sheet.grabberWidth,
                        height: sheet.grabberHeight,
                        margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: sheet.grabberColor,
                          borderRadius: BorderRadius.circular(sheet.grabberHeight / 2),
                        ),
                      ),
                      SizedBox(
                        height: _height,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: _bandWidth,
                              height: _extent,
                              decoration: SuperellipseDecoration(
                                borderRadius: AppRadius.chip,
                                color: theme.text.withValues(alpha: 0.05),
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _Wheel(
                                  count: 24,
                                  initial: _hour,
                                  extent: _extent,
                                  style: digits,
                                  onChanged: (v) => _hour = v,
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                                  child: Text(
                                    ':',
                                    style: digits.copyWith(color: theme.textSecondary),
                                  ),
                                ),
                                _Wheel(
                                  count: 60,
                                  initial: _minute,
                                  extent: _extent,
                                  style: digits,
                                  onChanged: (v) => _minute = v,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One curved digit wheel. [ListWheelScrollView] with [FixedExtentScrollPhysics]
/// gives the rounded barrel and the native scroll-and-snap; the CupertinoPicker
/// numbers - diameterRatio, squeeze, faded off-center rows - are set here rather
/// than importing the Cupertino widget. Digits are CENTERED: the barrel rotates
/// around the wheel's centerline, so an off-center digit would fan sideways as it
/// curves. Fixed width, sat beside the colon.
class _Wheel extends StatefulWidget {
  const _Wheel({
    required this.count,
    required this.initial,
    required this.extent,
    required this.style,
    required this.onChanged,
  });

  final int count;
  final int initial;
  final double extent;
  final TextStyle style;
  final ValueChanged<int> onChanged;

  @override
  State<_Wheel> createState() => _WheelState();
}

class _WheelState extends State<_Wheel> {
  static const _width = 108.0;

  // Clamp defensively: an out-of-range initial would leave the controller off
  // its item list and, since onSelectedItemChanged never fires on init, commit
  // that stale value straight back.
  late final FixedExtentScrollController _controller = FixedExtentScrollController(
    initialItem: widget.initial.clamp(0, widget.count - 1),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // A tap on an off-center digit rolls it up to the selection, the way tapping
  // a row does on the OS picker. onSelectedItemChanged carries the haptics and
  // the value as the animation crosses each item.
  void _rollTo(int index, Duration duration) {
    _controller.animateToItem(index, duration: duration, curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) {
    final roll = context.motionNow.indicator;
    return SizedBox(
      width: _width,
      child: ListWheelScrollView.useDelegate(
        controller: _controller,
        itemExtent: widget.extent,
        physics: const FixedExtentScrollPhysics(),
        // The CupertinoPicker feel: a pronounced barrel curve and a slight
        // squeeze, with the off-center rows fading as they round away.
        diameterRatio: 1.1,
        squeeze: 1.25,
        overAndUnderCenterOpacity: 0.4,
        onSelectedItemChanged: (i) {
          Haptics.selection();
          widget.onChanged(i);
        },
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: widget.count,
          builder: (context, i) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _rollTo(i, roll),
            child: Center(child: Text(i.toString().padLeft(2, '0'), style: widget.style)),
          ),
        ),
      ),
    );
  }
}
