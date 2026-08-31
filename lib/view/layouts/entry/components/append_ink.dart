import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

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
