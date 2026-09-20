import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/superellipse.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/core/utils/haptics.dart';
import 'package:opentranscribe/view/widgets/app_sheet.dart';

/// A time of day as whole hours and minutes.
typedef TimeOfDayValue = ({int hour, int minute});

/// The app's time picker: two curved digit wheels (hours 00-23, minutes 00-59)
/// in the house tabular figures, over an ink selection pill that hugs the
/// wheels. Built on [ListWheelScrollView] (the widget CupertinoPicker itself
/// wraps) for the rounded barrel look and its FixedExtent scroll-and-snap, but
/// styled in our ink instead of the OS overlay. It rides the shared sheet: the
/// wheels keep their own vertical drags and a drag anywhere else moves the
/// sheet. There is no confirm, so every close commits the wheels' time.
Future<TimeOfDayValue> showTimePickerSheet(
  BuildContext context, {
  required int hour,
  required int minute,
}) async {
  // Clamped here, not per wheel: onSelectedItemChanged never fires on init, so
  // an out-of-range start would otherwise come straight back as the result.
  var picked = (hour: hour.clamp(0, 23), minute: minute.clamp(0, 59));
  await showAppSheet<void>(
    context,
    builder: (context) => _TimeWheels(
      initial: picked,
      onHour: (value) => picked = (hour: value, minute: picked.minute),
      onMinute: (value) => picked = (hour: picked.hour, minute: value),
    ),
  );
  return picked;
}

class _TimeWheels extends StatelessWidget {
  const _TimeWheels({required this.initial, required this.onHour, required this.onMinute});

  final TimeOfDayValue initial;
  final ValueChanged<int> onHour;
  final ValueChanged<int> onMinute;

  static const _extent = 42.0;
  static const _height = 210.0;
  static const _digitSize = 26.0;
  // The selection pill hugs the two wheels rather than spanning the sheet: a
  // full-width band left bare margins on the phone's wider sheet.
  static const _bandWidth = 240.0;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final digits = AppType.digits(AppType.title).copyWith(color: theme.text, fontSize: _digitSize);
    return SizedBox(
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
                initial: initial.hour,
                extent: _extent,
                style: digits,
                onChanged: onHour,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: Text(':', style: digits.copyWith(color: theme.textSecondary)),
              ),
              _Wheel(
                count: 60,
                initial: initial.minute,
                extent: _extent,
                style: digits,
                onChanged: onMinute,
              ),
            ],
          ),
        ],
      ),
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

  late final FixedExtentScrollController _controller = FixedExtentScrollController(
    initialItem: widget.initial,
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
