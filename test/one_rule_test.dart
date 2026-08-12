import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The one rule (CLAUDE.md): nothing leaves the phone. That is architecture,
/// not policy, and prose alone cannot enforce it - a stray `import
/// 'package:http/http.dart'` would compile, analyze clean, and ship. These
/// tests make the rule mechanical, the same way no_framework_imports_test.dart
/// makes the material/cupertino ban mechanical.
void main() {
  // Anchored to the start of an import/export statement, like the
  // material/cupertino guard, so a doc comment mentioning "http" never trips it.
  final bannedImport = RegExp(r'''^\s*(?:import|export)\s+['"]package:http/''', multiLine: true);

  // Word-boundary so these never match inside a longer identifier or a
  // doc-comment mention. Plain dart:io (File, Directory) stays legal; only
  // its network surface is banned.
  final bannedDartSymbol = RegExp(
    r'\b(HttpClient\(|HttpServer|Socket\.connect|SecureSocket|WebSocket\.connect)',
  );

  final bannedAsset = RegExp(r'\b(Lottie\.network|NetworkAssetBundle|Image\.network)\b');

  final packageDirs = Directory('packages').listSync().whereType<Directory>().toList();

  test('lib/ and every plugin package never touch the network', () {
    final dartRoots = [
      Directory('lib'),
      for (final pkg in packageDirs) Directory('${pkg.path}/lib'),
    ];

    final offenders = <String>[];
    final files = <File>[
      for (final root in dartRoots)
        if (root.existsSync()) ...root.listSync(recursive: true).whereType<File>(),
    ].where((f) => f.path.endsWith('.dart'));

    for (final file in files) {
      final contents = file.readAsStringSync();
      if (bannedImport.hasMatch(contents) ||
          bannedDartSymbol.hasMatch(contents) ||
          bannedAsset.hasMatch(contents)) {
        offenders.add(file.path);
      }
    }

    expect(offenders, isEmpty, reason: offenders.join('\n'));

    for (final root in dartRoots) {
      if (!root.existsSync()) continue;
      final count = files.where((f) => f.path.startsWith(root.path)).length;
      expect(count, greaterThan(0), reason: '${root.path} contributed no Dart files to the scan');
    }
  });

  // Strip // line comments first so a prose mention of these symbols (e.g. in
  // a doc comment explaining why the app avoids them) can never trip the test.
  final lineComment = RegExp(r'//.*$', multiLine: true);
  final bannedSwiftSymbol = RegExp(
    r'\b(URLSession|NWConnection|CFStreamCreatePairWithSocket|dataTask\()',
  );

  test('native sources never open a connection', () {
    final swiftRoots = [
      Directory('ios'),
      for (final pkg in packageDirs) Directory('${pkg.path}/ios'),
    ];

    final offenders = <String>[];
    final files = <File>[
      for (final root in swiftRoots)
        if (root.existsSync()) ...root.listSync(recursive: true).whereType<File>(),
    ].where((f) => f.path.endsWith('.swift'));

    for (final file in files) {
      final stripped = file.readAsStringSync().replaceAll(lineComment, '');
      if (bannedSwiftSymbol.hasMatch(stripped)) offenders.add(file.path);
    }

    expect(offenders, isEmpty, reason: offenders.join('\n'));

    for (final root in swiftRoots) {
      if (!root.existsSync()) continue;
      final count = files.where((f) => f.path.startsWith(root.path)).length;
      expect(count, greaterThan(0), reason: '${root.path} contributed no Swift files to the scan');
    }
  });
}
