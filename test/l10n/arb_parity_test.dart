import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A key present in the template but not a locale falls back to English at
/// runtime, silently shipping untranslated copy; the reverse is a dead key.
/// Every locale must carry exactly the template's message keys.
void main() {
  Set<String> messageKeys(File arb) {
    final map = jsonDecode(arb.readAsStringSync()) as Map<String, dynamic>;
    return map.keys.where((k) => !k.startsWith('@')).toSet();
  }

  test('every app_*.arb carries exactly the template key set', () {
    final template = File('lib/l10n/app_en.arb');
    final expected = messageKeys(template);

    final locales = Directory(
      'lib/l10n',
    ).listSync().whereType<File>().where((f) => f.path.endsWith('.arb') && f.path != template.path);

    final report = <String>[];
    for (final arb in locales) {
      final keys = messageKeys(arb);
      final missing = expected.difference(keys);
      final extra = keys.difference(expected);
      if (missing.isNotEmpty) report.add('${arb.path} missing: ${missing.join(', ')}');
      if (extra.isNotEmpty) report.add('${arb.path} extra: ${extra.join(', ')}');
    }

    expect(report, isEmpty, reason: report.join('\n'));
  });
}
