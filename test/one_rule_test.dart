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

  test('lib/ and the vendored plugin never touch the network', () {
    final offenders = <String>[];
    final files = <File>[
      ...Directory('lib').listSync(recursive: true).whereType<File>(),
      ...Directory('packages/liquid/lib').listSync(recursive: true).whereType<File>(),
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
  });

  // Strip // line comments first so a prose mention of these symbols (e.g. in
  // a doc comment explaining why the app avoids them) can never trip the test.
  final lineComment = RegExp(r'//.*$', multiLine: true);
  final bannedSwiftSymbol = RegExp(
    r'\b(URLSession|NWConnection|CFStreamCreatePairWithSocket|dataTask\()',
  );

  test('native sources never open a connection', () {
    final offenders = <String>[];
    final files = <File>[
      ...Directory('ios').listSync(recursive: true).whereType<File>(),
      ...Directory('packages/liquid/ios').listSync(recursive: true).whereType<File>(),
    ].where((f) => f.path.endsWith('.swift'));

    for (final file in files) {
      final stripped = file.readAsStringSync().replaceAll(lineComment, '');
      if (bannedSwiftSymbol.hasMatch(stripped)) offenders.add(file.path);
    }

    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
