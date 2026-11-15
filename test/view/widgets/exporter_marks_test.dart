import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/models/exporter_descriptor.dart';
import 'package:opentranscribe/view/widgets/exporter_marks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const shipped = [
    ExporterDescriptor(
      exporterId: 'markdown',
      format: ExportFormat.markdown,
      logo: 'assets/brand/markdown.svg',
    ),
    ExporterDescriptor(
      exporterId: 'obsidian',
      format: ExportFormat.obsidian,
      logo: 'assets/brand/obsidian.svg',
    ),
    ExporterDescriptor(
      exporterId: 'html',
      format: ExportFormat.web,
      logo: 'assets/brand/safari.svg',
    ),
  ];

  test('marks are not at hand before they are rasterized, and are once they have been', () async {
    final pair = shipped.take(2).toList();
    expect(exporterMarksNow(pair), isNull);
    final marks = await exporterMarks(pair);
    expect(exporterMarksNow(pair), same(marks));
    expect(exporterMarksNow(pair.reversed.toList()), same(marks));
  });

  test('a different set of formats never reads another set\'s marks', () async {
    await exporterMarks(shipped);
    final one = await exporterMarks(shipped.take(1).toList());
    expect(one.keys, ['markdown']);
  });

  test('every shipped format mark rasterizes to a square bitmap for the menu, '
      'and a missing one is left out', () async {
    const gone = ExporterDescriptor(
      exporterId: 'gone',
      format: ExportFormat.web,
      logo: 'assets/brand/gone.svg',
    );
    final descriptors = [...shipped, gone];
    final marks = await exporterMarks(descriptors);
    expect(marks.keys, ['markdown', 'obsidian', 'html']);
    for (final bytes in marks.values) {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, frame.image.height);
      expect(frame.image.width, greaterThan(0));
      final rgba = await frame.image.toByteData();
      final alphas = [for (var i = 3; i < rgba!.lengthInBytes; i += 4) rgba.getUint8(i)];
      expect(alphas.any((a) => a > 0), isTrue);
      expect(alphas.any((a) => a == 0), isTrue);
    }
  });
}
