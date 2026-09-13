import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:opentranscribe/view/widgets/ink_forecast.dart';
import 'package:opentranscribe/view/widgets/invisible_ink.dart';

/// The words of [addition] as they will look once they follow [base] in one
/// paragraph laid out at [width]: the region from the addition's first line
/// down, painted at [pixelRatio] with the base transparent and the addition
/// in [color]. [top] is that region's offset in the paragraph, [size] its
/// logical size. Only the tail is rasterized, so a long entry costs no more
/// than its last lines.
@visibleForTesting
Future<({ui.Image image, Size size, double top})> paintAppendedInk({
  required String base,
  required String addition,
  required double width,
  required TextStyle style,
  required TextScaler textScaler,
  required double pixelRatio,
  required Color color,
  Locale? locale,
}) async {
  final head = base.trim();
  final tail = addition.trim();
  final painter = TextPainter(
    text: TextSpan(
      children: [
        if (head.isNotEmpty)
          TextSpan(
            text: head,
            style: style.copyWith(color: const Color(0x00000000)),
          ),
        if (tail.isNotEmpty)
          TextSpan(
            text: head.isEmpty ? tail : ' $tail',
            style: style.copyWith(color: color),
          ),
      ],
    ),
    textDirection: TextDirection.ltr,
    textScaler: textScaler,
    locale: locale,
  )..layout(maxWidth: width);
  final full = painter.size;
  var top = 0.0;
  if (head.isNotEmpty && tail.isNotEmpty) {
    final start = head.length + 1;
    final boxes = painter.getBoxesForSelection(
      TextSelection(baseOffset: start, extentOffset: start + 1),
      boxHeightStyle: ui.BoxHeightStyle.max,
    );
    if (boxes.isNotEmpty) top = boxes.first.top;
  }
  final size = Size(full.width, full.height - top);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..scale(pixelRatio)
    ..translate(0, -top);
  painter.paint(canvas, Offset.zero);
  painter.dispose();
  final picture = recorder.endRecording();
  final image = await picture.toImage(
    (size.width * pixelRatio).ceil().clamp(1, 1 << 14),
    (size.height * pixelRatio).ceil().clamp(1, 1 << 14),
  );
  picture.dispose();
  return (image: image, size: size, top: top);
}

/// The ink of [paintAppendedInk] as spark points in the region's own
/// coordinates, with the region's size and offset. Null only when the
/// rasterizer handed back no pixels.
Future<({Float32List points, Size size, double top})?> appendedInkPoints({
  required String base,
  required String addition,
  required double width,
  required TextStyle style,
  required TextScaler textScaler,
  required double pixelRatio,
  required Color color,
  Locale? locale,
}) async {
  final painted = await paintAppendedInk(
    base: base,
    addition: addition,
    width: width,
    style: style,
    textScaler: textScaler,
    pixelRatio: pixelRatio,
    color: color,
    locale: locale,
  );
  final image = painted.image;
  final data = await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
  final (w, h) = (image.width, image.height);
  image.dispose();
  if (data == null) return null;
  final points = sampleInkPoints(data, width: w, height: h, pixelRatio: pixelRatio);
  return (points: points, size: painted.size, top: painted.top);
}

/// [filler] cut so that, laid after [base] in one paragraph at [width], it
/// runs to no more than [maxLines] lines of its own, ending where a line
/// breaks (a whole word, or a character in a script without spaces). All of
/// it when it fits; empty when nothing does.
String appendFillerWithin({
  required String base,
  required String filler,
  required double width,
  required TextStyle style,
  required TextScaler textScaler,
  required int maxLines,
  Locale? locale,
}) {
  final head = base.trim();
  final tail = filler.trim();
  if (tail.isEmpty || maxLines <= 0) return '';
  final start = head.isEmpty ? 0 : head.length + 1;
  final painter = TextPainter(
    text: TextSpan(text: head.isEmpty ? tail : '$head $tail', style: style),
    textDirection: TextDirection.ltr,
    textScaler: textScaler,
    locale: locale,
  )..layout(maxWidth: width);
  try {
    final lines = painter.computeLineMetrics();
    final startTop = painter.getOffsetForCaret(TextPosition(offset: start), Rect.zero).dy;
    var top = 0.0;
    var first = 0;
    for (final (i, line) in lines.indexed) {
      if (startTop < top + line.height - 0.5) {
        first = i;
        break;
      }
      top += line.height;
    }
    final last = first + maxLines - 1;
    if (last >= lines.length - 1) return tail;
    var lastTop = top;
    for (var i = first; i < last; i++) {
      lastTop += lines[i].height;
    }
    final onLast = painter.getPositionForOffset(Offset(width, lastTop + lines[last].height / 2));
    final end = painter.getLineBoundary(onLast).end - start;
    return end <= 0 ? '' : tail.substring(0, end).trimRight();
  } finally {
    painter.dispose();
  }
}

/// The words a take's ink stands for: about [characters] of [sample]'s words
/// laid after [base], up to the lines a screen of [screenHeight] holds (past
/// that no one sees ink, and the landing reshapes it to the real words
/// anyway). Empty without a forecast.
String appendPending({
  required int? characters,
  required String sample,
  required String base,
  required double width,
  required double screenHeight,
  required TextStyle style,
  required TextScaler textScaler,
  Locale? locale,
}) {
  if (characters == null) return '';
  final size = textScaler.scale(style.fontSize!);
  final lines = screenLines(screenHeight: screenHeight, style: style, textScaler: textScaler);
  return appendFillerWithin(
    base: base,
    filler: forecastFiller(
      sample: sample,
      characters: characters,
      width: width,
      fontSize: size,
      lines: lines,
    ),
    width: width,
    style: style,
    textScaler: textScaler,
    maxLines: lines,
    locale: locale,
  );
}

/// How many lines of [style] a screen of [screenHeight] holds: as far as ink
/// is worth laying out, since nothing past it is seen.
int screenLines({
  required double screenHeight,
  required TextStyle style,
  required TextScaler textScaler,
}) =>
    math.max(1, (screenHeight / (textScaler.scale(style.fontSize!) * (style.height ?? 1))).floor());

/// What a landing does with the take's ink.
enum AppendLanding {
  /// The words show at once and the ink goes: nothing grew, the ink never
  /// formed, the live words already stood there, or motion is reduced.
  swap,

  /// The ink already has the landed words' shape: it only dissolves.
  dissolve,

  /// The ink is repainted in the landed words' shape first, then dissolves.
  reshape,
}

/// How a take lands on the words: [grew] when they only gained a tail,
/// [liveShown] when its live words stood in the tail's place, [inkShown]
/// when the ink is up (not faded out), [laidOut] when its layout is known, and
/// [matches] when the ink was already painted from the landed words.
AppendLanding appendLanding({
  required bool grew,
  required bool liveShown,
  required bool inkShown,
  required bool laidOut,
  required bool reduceMotion,
  required bool matches,
}) {
  if (!grew || liveShown || !inkShown || !laidOut || reduceMotion) return AppendLanding.swap;
  return matches ? AppendLanding.dissolve : AppendLanding.reshape;
}
