import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The app draws every control itself; these imports must never come back.
void main() {
  // Anchored to the start of an import/export statement (not a bare substring):
  // lib/ mentions "material" in many doc comments, which must not trip this.
  // Catches single- and double-quoted, import and export, and the src/ deep path.
  final banned = RegExp(
    r'''^\s*(?:import|export)\s+['"]package:flutter/(?:src/)?(?:material|cupertino)''',
    multiLine: true,
  );

  // The one exempt file: native text selection (SelectionArea) lives in
  // material.dart and cannot come from widgets.dart.
  bool isExempt(String path) => path.endsWith('view/widgets/selectable_prose.dart');

  test('lib/ is free of material and cupertino imports', () {
    final offenders = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !isExempt(f.path));

    for (final file in files) {
      if (banned.hasMatch(file.readAsStringSync())) offenders.add(file.path);
    }

    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
