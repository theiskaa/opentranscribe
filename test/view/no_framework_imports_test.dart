import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The app draws every control itself; these imports must never come back.
void main() {
  const banned = ['package:flutter/material.dart', 'package:flutter/cupertino.dart'];

  test('lib/ is free of material and cupertino imports', () {
    final offenders = <String>[];
    final files = Directory(
      'lib',
    ).listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

    for (final file in files) {
      final content = file.readAsStringSync();
      for (final import in banned) {
        if (content.contains("import '$import'")) {
          offenders.add('${file.path} imports $import');
        }
      }
    }

    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
