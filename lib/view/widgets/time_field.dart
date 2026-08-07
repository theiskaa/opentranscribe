import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/formatting.dart';
import 'package:opentranscribe/view/widgets/rolling_text.dart';
import 'package:opentranscribe/view/widgets/time_picker_sheet.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';

/// A settings row that shows a time and, on tap, opens the app's own drawn time
/// picker to change it. The picker commits on tap-outside; [onChanged] fires
/// only when that lands on a different time, so a dismissal or a no-op reselect
/// leaves the value untouched. The shown time odometer-rolls to a new value,
/// like the home date title.
class TimeField extends StatefulWidget {
  const TimeField({
    required this.label,
    required this.hour,
    required this.minute,
    required this.onChanged,
    super.key,
  });

  final String label;
  final int hour;
  final int minute;
  final void Function(int hour, int minute) onChanged;

  @override
  State<TimeField> createState() => _TimeFieldState();
}

class _TimeFieldState extends State<TimeField> {
  // Roll direction: +1 when the new time is later in the day, -1 earlier, so the
  // digits travel the way the value moved (the home title's convention).
  int _direction = 1;

  @override
  void didUpdateWidget(TimeField old) {
    super.didUpdateWidget(old);
    final before = old.hour * 60 + old.minute;
    final after = widget.hour * 60 + widget.minute;
    if (after != before) _direction = after > before ? 1 : -1;
  }

  /// The chosen time as 24-hour HH:mm, matching the picker wheels (which run
  /// 00-23), so a picked 17:01 never reads back as 5:01 PM.
  String _formatted(BuildContext context) =>
      DateFormat.Hm(localeTag(context)).format(DateTime(2000, 1, 1, widget.hour, widget.minute));

  Future<void> _pick(BuildContext context) async {
    final picked = await showTimePickerSheet(context, hour: widget.hour, minute: widget.minute);
    // Closing the sheet commits the current time; skip the write when it did not
    // actually change.
    if (picked == null || (picked.hour == widget.hour && picked.minute == widget.minute)) return;
    widget.onChanged(picked.hour, picked.minute);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Touchable(
      onTap: () => _pick(context),
      haptic: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(widget.label, style: AppType.subhead.copyWith(color: theme.text)),
            ),
            RollingText(
              text: _formatted(context),
              style: AppType.digits(AppType.subhead).copyWith(color: theme.textSecondary),
              direction: _direction,
            ),
            const SizedBox(width: AppSpacing.xs),
            AppIcon(AppIcons.chevronForward, size: 14, color: theme.textSecondary),
          ],
        ),
      ),
    );
  }
}
