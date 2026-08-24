import 'package:flutter/widgets.dart';

/// The [AnimatedSwitcher.layoutBuilder] for swaps that melt in place: faces
/// stack top-left so old and new content share an origin while they
/// crossfade, where the default center pin would drift both mid-fade.
Widget meltStack(Widget? current, List<Widget> previous) =>
    Stack(alignment: Alignment.topLeft, children: [...previous, ?current]);
