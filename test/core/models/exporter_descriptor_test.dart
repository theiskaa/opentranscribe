import 'package:flutter_test/flutter_test.dart';

import 'package:opentranscribe/core/models/exporter_descriptor.dart';

void main() {
  const descriptors = [
    ExporterDescriptor(exporterId: 'markdown', displayName: 'Markdown', logo: 'markdown.svg'),
    ExporterDescriptor(exporterId: 'obsidian', displayName: 'Obsidian', logo: 'obsidian.svg'),
  ];

  test('a stored format that still ships is kept', () {
    expect(resolveFormatId('obsidian', descriptors), 'obsidian');
  });

  test('a stored format that no longer ships falls back to the first', () {
    expect(resolveFormatId('notion', descriptors), 'markdown');
  });
}
