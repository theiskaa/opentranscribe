import 'package:flutter_test/flutter_test.dart';

import 'package:opentranscribe/core/models/exporter_descriptor.dart';

void main() {
  const descriptors = [
    ExporterDescriptor(exporterId: 'markdown', format: ExportFormat.markdown, logo: 'm.svg'),
    ExporterDescriptor(exporterId: 'obsidian', format: ExportFormat.obsidian, logo: 'o.svg'),
  ];

  test('a stored format that still ships is kept', () {
    expect(resolveFormatId('obsidian', descriptors), 'obsidian');
  });

  test('a stored format that no longer ships falls back to the first', () {
    expect(resolveFormatId('notion', descriptors), 'markdown');
  });
}
