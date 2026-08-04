import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/reflect/reflection_period.dart';
import 'package:opentranscribe/core/state/reflections_cubit.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/segmented_control.dart';

/// The reflections screen's Day / Week / Month switch, sized to sit compactly in
/// the bar title. It offers the periods the surface is showing (those enabled or
/// holding history) and drives which one the pager reads. On iOS 26 it is the
/// native Liquid Glass segmented control; below it, the app's drawn one.
///
/// Reads the [ReflectionsCubit] directly so it can drop into the bar's title
/// slot; renders nothing when there is only one period to switch between.
class PeriodSwitcher extends StatelessWidget {
  const PeriodSwitcher({super.key});

  static const _height = 34.0;
  static const _segmentWidth = 74.0;

  static String _label(ReflectionPeriod period, AppLocalizations l10n) => switch (period) {
    ReflectionPeriod.daily => l10n.reflectionPeriodDay,
    ReflectionPeriod.weekly => l10n.reflectionPeriodWeek,
    ReflectionPeriod.monthly => l10n.reflectionPeriodMonth,
  };

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ReflectionsCubit>().state;
    final periods = state.periods;
    if (periods.length <= 1) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;

    // The bar centers its title in a loose slot, so the switcher fixes its own
    // width; the native platform view has no intrinsic size to fall back on.
    return SizedBox(
      width: periods.length * _segmentWidth,
      child: AppSegmentedControl<ReflectionPeriod>(
        segments: [for (final period in periods) (period, _label(period, l10n))],
        selected: state.viewedPeriod,
        onChanged: (period) => context.read<ReflectionsCubit>().setViewedPeriod(period),
        height: _height,
      ),
    );
  }
}
