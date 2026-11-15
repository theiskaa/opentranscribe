import 'package:flutter/widgets.dart';

/// The iPhone Duo's cover display as measured: the vertical status bar's
/// column on the right, the home indicator below.
const coverSize = Size(466, 678);
const coverPadding = EdgeInsets.only(right: 84, bottom: 34);

/// The inner display held wide, flat or folded: the bar's column on the
/// right, the home indicator below.
const wideSize = Size(951, 669);
const widePadding = EdgeInsets.only(right: 84, bottom: 34);

/// The fold as measured on the inner display: where its band starts from the
/// left or top edge, and how deep it is, held wide and tall alike.
const foldStart = 456.0;
const foldDepth = 40.0;

/// The inner display held tall: the bar along the top, as on any iPhone.
const tallSize = Size(669, 951);
const tallPadding = EdgeInsets.only(top: 82, bottom: 34);

/// One half of a side-by-side Split View on the inner display held wide.
const splitHalfWidth = 475.0;

/// The narrower side of an uneven Split View on the inner display.
const sideHalfWidth = 334.0;

/// A regular portrait iPhone: no side insets at all.
const iphoneSize = Size(402, 874);
const iphonePadding = EdgeInsets.only(top: 62, bottom: 34);

/// The cover display as `MediaQuery` reports it.
const coverMedia = MediaQueryData(
  size: coverSize,
  padding: coverPadding,
  viewPadding: coverPadding,
);

/// A regular portrait iPhone as `MediaQuery` reports it.
const iphoneMedia = MediaQueryData(
  size: iphoneSize,
  padding: iphonePadding,
  viewPadding: iphonePadding,
);
