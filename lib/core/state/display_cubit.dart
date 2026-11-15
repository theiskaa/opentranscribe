import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/models/display_signal.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/utils/display_regions.dart';

/// The display as the pane layout needs it: the latest signal, and the width
/// the journal pane keeps beside a detail.
@immutable
final class DisplayState {
  const DisplayState({required this.signal, this.closedContentWidth = AppDuo.closedContentWidth});

  final DisplaySignal signal;

  /// The token until the closed device's window is seen, then that window's
  /// content width, so the leading pane matches the real cover after one
  /// fold. Held in memory only.
  final double closedContentWidth;

  @override
  bool operator ==(Object other) =>
      other is DisplayState &&
      other.signal == signal &&
      other.closedContentWidth == closedContentWidth;

  @override
  int get hashCode => Object.hash(signal, closedContentWidth);
}

/// Mirrors [DisplayRegionsMonitor] for the pane layout.
class DisplayCubit extends Cubit<DisplayState> {
  DisplayCubit({required DisplayRegionsMonitor monitor})
    : super(_next(const DisplayState(signal: DisplaySignal.unsupported), monitor.current)) {
    _sub = monitor.changes.listen((signal) {
      emit(_next(state, signal));
    });
  }

  late final StreamSubscription<DisplaySignal> _sub;

  static DisplayState _next(DisplayState previous, DisplaySignal signal) => DisplayState(
    signal: signal,
    closedContentWidth: closedContentWidthOf(signal) ?? previous.closedContentWidth,
  );

  /// The content width [signal] shows when it is the closed device's window,
  /// within [AppDuo.closedContentWidthMin] and [AppDuo.closedContentWidthMax];
  /// null for any other window. Only a full-screen compact window with its
  /// bar at the side and no fold counts: a Split View half or a Slide Over
  /// window on the open device is compact too.
  static double? closedContentWidthOf(DisplaySignal signal) {
    if (!signal.supported ||
        !signal.fullScreen ||
        signal.horizontal != SizeClass.compact ||
        signal.division != null) {
      return null;
    }
    final barInset = switch (signal.barSide) {
      BarSide.left => signal.padding.left,
      BarSide.right => signal.padding.right,
      BarSide.none => 0.0,
    };
    if (barInset <= 0) return null;
    return (signal.size.width - signal.padding.horizontal).clamp(
      AppDuo.closedContentWidthMin,
      AppDuo.closedContentWidthMax,
    );
  }

  @override
  Future<void> close() async {
    await _sub.cancel();
    return super.close();
  }
}
