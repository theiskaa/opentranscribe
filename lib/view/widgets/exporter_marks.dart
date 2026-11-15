import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter_svg/flutter_svg.dart';

import 'package:opentranscribe/core/models/exporter_descriptor.dart';

/// The raster side, in pixels: the GitHub mark's, so every bitmap a menu
/// carries downscales from the same master to the row's glyph size.
const int _rasterSide = 144;

/// Keyed by the set of exporter ids, so a different registry never reads
/// another's marks.
final Map<String, Future<Map<String, Uint8List>>> _pending = {};
final Map<String, Map<String, Uint8List>> _resolved = {};

String _keyOf(List<ExporterDescriptor> descriptors) =>
    ([for (final d in descriptors) d.exporterId]..sort()).join('\n');

/// The marks [exporterMarks] has already rasterized for [descriptors], or
/// null before they land, so a later screen can start with them in hand.
Map<String, Uint8List>? exporterMarksNow(List<ExporterDescriptor> descriptors) =>
    _resolved[_keyOf(descriptors)];

/// Each format's mark as PNG bytes keyed by exporter id, for menu rows: a
/// menu takes a bitmap, never an SVG. Rasterized once per launch. Only the
/// alpha counts, as both menus draw a mark as a template in their own ink,
/// so a branded mark reads as its silhouette there. A mark that fails to
/// rasterize is left out and its row goes without one.
Future<Map<String, Uint8List>> exporterMarks(List<ExporterDescriptor> descriptors) {
  final key = _keyOf(descriptors);
  return _pending[key] ??= _rasterizeAll(descriptors).then((marks) => _resolved[key] = marks);
}

Future<Map<String, Uint8List>> _rasterizeAll(List<ExporterDescriptor> descriptors) async {
  final marks = <String, Uint8List>{};
  for (final descriptor in descriptors) {
    try {
      marks[descriptor.exporterId] = await _rasterize(descriptor.logo);
    } catch (_) {
      // An unbundled or broken asset costs its row a mark, nothing more.
    }
  }
  return marks;
}

Future<Uint8List> _rasterize(String asset) async {
  final info = await vg.loadPicture(SvgAssetLoader(asset), null);
  try {
    final size = info.size;
    final scale = _rasterSide / math.max(size.width, size.height);
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)
      // A mark that is not square sits centred in the square, never pinned
      // to a corner.
      ..translate((_rasterSide - size.width * scale) / 2, (_rasterSide - size.height * scale) / 2)
      ..scale(scale);
    canvas.drawPicture(info.picture);
    final picture = recorder.endRecording();
    final image = await picture.toImage(_rasterSide, _rasterSide);
    picture.dispose();
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('no PNG for $asset');
      return data.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  } finally {
    info.picture.dispose();
  }
}
