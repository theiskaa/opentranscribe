import 'package:flutter/widgets.dart';

/// The app's icon set: Apple SF Symbols served from a vendored 41-glyph subset
/// font (`assets/icons/sficons.ttf`, cut from the flutter_sficon package's
/// Apache-2.0 distribution). iOS-only app, per Apple's symbol terms. Regenerate
/// the subset to add a glyph; do not add icons from other sets. A constants
/// table like the color tokens, which is why it lives in theming, not view.
@staticIconProvider
abstract final class AppIcons {
  static const _family = 'sficons';

  /// SF Symbol `apple.logo`.
  static const IconData appleLogo = IconData(0x1008FA, fontFamily: _family);

  /// SF Symbol `arrow.counterclockwise`.
  static const IconData arrowCounterclockwise = IconData(0x100149, fontFamily: _family);

  /// SF Symbol `arrow.up.right`.
  static const IconData arrowUpRight = IconData(0x10012F, fontFamily: _family);

  /// SF Symbol `bell`.
  static const IconData bell = IconData(0x1002D9, fontFamily: _family);

  /// SF Symbol `bell.fill`.
  static const IconData bellFill = IconData(0x1002DA, fontFamily: _family);

  /// SF Symbol `calendar` (the monthly reflection marker).
  static const IconData calendar = IconData(0x100249, fontFamily: _family);

  /// SF Symbol `1.calendar` (the daily reflection marker).
  static const IconData oneCalendar = IconData(0x103326, fontFamily: _family);

  /// SF Symbol `7.calendar` (the weekly reflection marker).
  static const IconData sevenCalendar = IconData(0x10332C, fontFamily: _family);

  /// SF Symbol `checkmark`.
  static const IconData checkmark = IconData(0x100185, fontFamily: _family);

  /// SF Symbol `chevron.backward`.
  static const IconData chevronBackward = IconData(0x100BF6, fontFamily: _family);

  /// SF Symbol `chevron.forward`.
  static const IconData chevronForward = IconData(0x100BFB, fontFamily: _family);

  /// SF Symbol `clock.arrow.circlepath` (the history clock).
  static const IconData clockHistory = IconData(0x1008D4, fontFamily: _family);

  /// SF Symbol `document.on.document`.
  static const IconData docOnDoc = IconData(0x100241, fontFamily: _family);

  /// SF Symbol `ellipsis`.
  static const IconData ellipsis = IconData(0x100360, fontFamily: _family);

  /// SF Symbol `gearshape.fill`.
  static const IconData gearshapeFill = IconData(0x1008CC, fontFamily: _family);

  /// SF Symbol `gearshape` (the outline gear).
  static const IconData gearshape = IconData(0x1008CB, fontFamily: _family);

  /// SF Symbol `globe`.
  static const IconData globe = IconData(0x1001AA, fontFamily: _family);

  /// SF Symbol `house.fill`.
  static const IconData houseFill = IconData(0x10039F, fontFamily: _family);

  /// SF Symbol `icloud`.
  static const IconData icloud = IconData(0x10030B, fontFamily: _family);

  /// SF Symbol `internaldrive`.
  static const IconData internaldrive = IconData(0x10097E, fontFamily: _family);

  /// SF Symbol `lock`.
  static const IconData lock = IconData(0x1003A0, fontFamily: _family);

  /// SF Symbol `magnifyingglass`.
  static const IconData magnifyingglass = IconData(0x1002AB, fontFamily: _family);

  /// SF Symbol `microphone`.
  static const IconData mic = IconData(0x1002B0, fontFamily: _family);

  /// SF Symbol `microphone.fill`.
  static const IconData micFill = IconData(0x1002B1, fontFamily: _family);

  /// SF Symbol `moon.fill`.
  static const IconData moonFill = IconData(0x1001BA, fontFamily: _family);

  /// SF Symbol `pause.fill`.
  static const IconData pauseFill = IconData(0x100286, fontFamily: _family);

  /// SF Symbol `pencil`.
  static const IconData pencil = IconData(0x10020A, fontFamily: _family);

  /// SF Symbol `play.fill`.
  static const IconData playFill = IconData(0x100284, fontFamily: _family);

  /// SF Symbol `slider.horizontal.3`.
  static const IconData sliderHorizontal3 = IconData(0x100306, fontFamily: _family);

  /// SF Symbol `sparkles`.
  static const IconData sparkles = IconData(0x1001BF, fontFamily: _family);

  /// SF Symbol `square.and.arrow.down`.
  static const IconData squareAndArrowDown = IconData(0x100204, fontFamily: _family);

  /// SF Symbol `square.and.arrow.up`.
  static const IconData squareAndArrowUp = IconData(0x100202, fontFamily: _family);

  /// SF Symbol `square.fill`.
  static const IconData squareFill = IconData(0x100093, fontFamily: _family);

  /// SF Symbol `stop.fill`.
  static const IconData stopFill = IconData(0x1006F7, fontFamily: _family);

  /// SF Symbol `sun.max`.
  static const IconData sunMax = IconData(0x1001AD, fontFamily: _family);

  /// SF Symbol `text.alignleft`.
  static const IconData textAlignleft = IconData(0x100300, fontFamily: _family);

  /// SF Symbol `text.quote`.
  static const IconData textQuote = IconData(0x1002FF, fontFamily: _family);

  /// SF Symbol `textformat`.
  static const IconData textformat = IconData(0x100152, fontFamily: _family);

  /// SF Symbol `trash`.
  static const IconData trash = IconData(0x100211, fontFamily: _family);

  /// SF Symbol `waveform`.
  static const IconData waveform = IconData(0x10066B, fontFamily: _family);

  /// SF Symbol `xmark`.
  static const IconData xmark = IconData(0x100184, fontFamily: _family);

  /// The SF Symbol NAME for a glyph, for native chrome (UIKit renders the
  /// real symbol; the vendored font is only for Flutter-drawn glyphs).
  static String sfSymbolName(IconData icon) =>
      const {
        0x1008FA: 'apple.logo',
        0x100149: 'arrow.counterclockwise',
        0x10012F: 'arrow.up.right',
        0x1002D9: 'bell',
        0x1002DA: 'bell.fill',
        0x100249: 'calendar',
        0x103326: '1.calendar',
        0x10332C: '7.calendar',
        0x100185: 'checkmark',
        0x100BF6: 'chevron.backward',
        0x100BFB: 'chevron.forward',
        0x1008D4: 'clock.arrow.circlepath',
        0x100241: 'doc.on.doc',
        0x100360: 'ellipsis',
        0x1008CB: 'gearshape',
        0x1008CC: 'gearshape.fill',
        0x1001AA: 'globe',
        0x10039F: 'house.fill',
        0x10030B: 'icloud',
        0x10097E: 'internaldrive',
        0x1003A0: 'lock',
        0x1002AB: 'magnifyingglass',
        0x1002B0: 'mic',
        0x1002B1: 'mic.fill',
        0x1001BA: 'moon.fill',
        0x100286: 'pause.fill',
        0x10020A: 'pencil',
        0x100284: 'play.fill',
        0x100306: 'slider.horizontal.3',
        0x1001BF: 'sparkles',
        0x100204: 'square.and.arrow.down',
        0x100202: 'square.and.arrow.up',
        0x100093: 'square.fill',
        0x1006F7: 'stop.fill',
        0x1001AD: 'sun.max',
        0x100300: 'text.alignleft',
        0x1002FF: 'text.quote',
        0x100152: 'textformat',
        0x100211: 'trash',
        0x10066B: 'waveform',
        0x100184: 'xmark',
      }[icon.codePoint] ??
      'circle';
}
