import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/reflect/reflection_period.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/segmented_control.dart';

/// The reflections screen's Day / Week / Month switch: a segmented control over
/// the [periods] the surface offers (those enabled or holding history), picking
/// which one the pager reads. The screen only mounts it when there is more than
/// one period to switch between.
class PeriodSwitcher extends StatelessWidget {
  const PeriodSwitcher({
    required this.periods,
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final List<ReflectionPeriod> periods;
  final ReflectionPeriod selected;
  final ValueChanged<ReflectionPeriod> onChanged;

  static String _label(ReflectionPeriod period, AppLocalizations l10n) => switch (period) {
    ReflectionPeriod.daily => l10n.reflectionPeriodDay,
    ReflectionPeriod.weekly => l10n.reflectionPeriodWeek,
    ReflectionPeriod.monthly => l10n.reflectionPeriodMonth,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppSegmentedControl<ReflectionPeriod>(
      segments: [for (final period in periods) (period, _label(period, l10n))],
      selected: selected,
      onChanged: onChanged,
    );
  }
}
