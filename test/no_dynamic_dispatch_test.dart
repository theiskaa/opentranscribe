import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The app is only what its compiled code says it is. Reaching a method or a
/// property by name at runtime is how an app changes behavior after review, so
/// App Review scans for the pattern (Guideline 5.6) whether or not the code can
/// run: an unreachable branch still ships the selector string in the binary.
void main() {
  // Line comments stripped first, so prose naming these symbols never trips the
  // scan, the same way the network guard reads its Swift.
  final lineComment = RegExp(r'//.*$', multiLine: true);

  final bannedSymbol = RegExp(
    r'\b(NSSelectorFromString|NSClassFromString|responds\(to:|method\(for:'
    r'|method_exchangeImplementations|class_replaceMethod|class_addMethod'
    r'|dlopen\(|dlsym\(|unsafeBitCast\()',
  );

  // Key-value coding reaches a property the compiler never checked. The
  // dictionary, UserDefaults and CALayer `forKey:` APIs are untouched.
  final bannedKvc = RegExp(r'\.(setValue\(.*forKey:|value\(forKey:)');

  test('native sources never reach a method or a property by name at runtime', () {
    final packageDirs = Directory('packages').listSync().whereType<Directory>();
    final roots = [Directory('ios'), for (final pkg in packageDirs) Directory('${pkg.path}/ios')];

    final files = <File>[
      for (final root in roots)
        if (root.existsSync()) ...root.listSync(recursive: true).whereType<File>(),
    ].where((f) => f.path.endsWith('.swift') && !f.path.contains('/.build/')).toList();

    final offenders = <String>[];
    for (final file in files) {
      final stripped = file.readAsStringSync().replaceAll(lineComment, '');
      if (bannedSymbol.hasMatch(stripped) || bannedKvc.hasMatch(stripped)) {
        offenders.add(file.path);
      }
    }

    expect(offenders, isEmpty, reason: offenders.join('\n'));

    for (final root in roots) {
      if (!root.existsSync()) continue;
      final count = files.where((f) => f.path.startsWith(root.path)).length;
      expect(count, greaterThan(0), reason: '${root.path} contributed no Swift files to the scan');
    }
  });
}
