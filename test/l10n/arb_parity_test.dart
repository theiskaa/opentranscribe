import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Structural guards over the .arb set. These check the SHAPE of every locale
/// against the template, not the quality of a translation: a key copied over in
/// English still passes. What they catch is what silently breaks at runtime -
/// a missing key (falls back to English), a stray key (dead), a dropped
/// `{placeholder}` (broken interpolation), or a duplicated key (JSON keeps the
/// last, hiding the shadowed one).
void main() {
  final template = File('lib/l10n/app_en.arb');
  final locales = Directory('lib/l10n')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.arb') && f.path != template.path)
      .toList();

  Map<String, dynamic> decode(File arb) =>
      jsonDecode(arb.readAsStringSync()) as Map<String, dynamic>;
  Set<String> messageKeys(Map<String, dynamic> arb) =>
      arb.keys.where((k) => !k.startsWith('@')).toSet();
  Set<String> placeholders(String value) =>
      RegExp(r'\{(\w+)\}').allMatches(value).map((m) => m.group(1)!).toSet();

  test('every app_*.arb carries exactly the template key set', () {
    final expected = messageKeys(decode(template));
    final report = <String>[];
    for (final arb in locales) {
      final keys = messageKeys(decode(arb));
      final missing = expected.difference(keys);
      final extra = keys.difference(expected);
      if (missing.isNotEmpty) report.add('${arb.path} missing: ${missing.join(', ')}');
      if (extra.isNotEmpty) report.add('${arb.path} extra: ${extra.join(', ')}');
    }
    expect(report, isEmpty, reason: report.join('\n'));
  });

  test('every localized message keeps the template placeholders', () {
    final expected = decode(template);
    final report = <String>[];
    for (final arb in locales) {
      final map = decode(arb);
      for (final key in messageKeys(expected)) {
        final value = map[key];
        if (value is! String) continue;
        final want = placeholders(expected[key] as String);
        final got = placeholders(value);
        if (want.difference(got).isNotEmpty || got.difference(want).isNotEmpty) {
          report.add('${arb.path} $key: expected {$want}, found {$got}');
        }
      }
    }
    expect(report, isEmpty, reason: report.join('\n'));
  });

  test('no app_*.arb repeats a top-level key', () {
    // JSON decoding keeps the last of two same-named keys, so a duplicate is
    // invisible to a parsed map; scan the raw text instead. Top-level keys sit
    // at the file's two-space indent; nested @-metadata fields are deeper.
    final topLevel = RegExp(r'^  "([^"]+)"\s*:', multiLine: true);
    final report = <String>[];
    for (final arb in [template, ...locales]) {
      final seen = <String>{};
      for (final m in topLevel.allMatches(arb.readAsStringSync())) {
        if (!seen.add(m.group(1)!)) report.add('${arb.path} repeats: ${m.group(1)}');
      }
    }
    expect(report, isEmpty, reason: report.join('\n'));
  });
}
