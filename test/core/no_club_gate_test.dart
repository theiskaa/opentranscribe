import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('nothing under core services or state reads the supporter tier except its holders', () {
    const allowed = {'support_cubit.dart', 'theme_cubit.dart', 'app_icon_cubit.dart'};
    const roots = ['lib/core/services', 'lib/core/state'];
    final offenders = <String>[];
    for (final root in roots) {
      final files = Directory(root)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .where((f) => !allowed.contains(f.uri.pathSegments.last));
      for (final file in files) {
        if (file.readAsStringSync().contains('isSupporter')) offenders.add(file.path);
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
