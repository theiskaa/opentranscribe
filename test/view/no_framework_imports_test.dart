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

  // The two exempt files: native text selection (SelectionArea) and the
  // editing handles, magnifier and menu live in material and cupertino and
  // cannot come from widgets.dart.
  const exempt = ['view/widgets/selectable_prose.dart', 'view/widgets/editable_prose.dart'];
  bool isExempt(String path) => exempt.any(path.endsWith);

  // First-party code only: packages/liquid stays out because wrapping native
  // chrome is its whole point.
  const roots = ['lib', 'packages/transcriber/lib', 'packages/reflections/lib'];

  test('first-party lib trees are free of material and cupertino imports', () {
    final offenders = <String>[];
    for (final root in roots) {
      final files = Directory(root)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => !isExempt(f.path));

      for (final file in files) {
        if (banned.hasMatch(file.readAsStringSync())) offenders.add(file.path);
      }
    }

    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
