import 'package:flutter_test/flutter_test.dart';

import 'package:opentranscribe/core/utils/language_tags.dart';

void main() {
  group('resolveSupportedTag', () {
    const supported = ['ar-SA', 'de-DE', 'en-AU', 'en-GB', 'en-US', 'tr-TR'];

    test('an exact match wins, case-insensitively, in the supported spelling', () {
      expect(resolveSupportedTag('en-US', supported), 'en-US');
      expect(resolveSupportedTag('EN-us', supported), 'en-US');
    });

    test('a region no model ships for resolves to the language, not to nothing', () {
      // The bug this exists for: Turkish phone in Georgia reports tr-GE.
      expect(resolveSupportedTag('tr-GE', supported), 'tr-TR');
    });

    test('among variants the home region wins over the alphabet', () {
      expect(resolveSupportedTag('en-GE', supported), 'en-US');
    });

    test('without a home-region variant the language-as-region variant wins', () {
      expect(resolveSupportedTag('az-XY', ['az-AZ', 'az-IR']), 'az-AZ');
    });

    test('a language with no variant at all is honestly unsupported', () {
      expect(resolveSupportedTag('ka-GE', supported), isNull);
      expect(resolveSupportedTag('en-US', const []), isNull);
    });

    test('a bare language tag resolves to its home-region variant', () {
      expect(resolveSupportedTag('pt', ['pt-BR', 'pt-PT']), 'pt-BR');
    });

    test('a script subtag never masks the region', () {
      expect(resolveSupportedTag('zh-GE', ['zh-Hans-CN']), 'zh-Hans-CN');
    });
  });

  group('languageTagCompare', () {
    test('major languages lead in speaker order, the rest follow alphabetically', () {
      final tags = ['da-DK', 'ar-SA', 'en-GB', 'tr-TR', 'en-US', 'fi-FI', 'zh-CN'];
      tags.sort(languageTagCompare);
      expect(tags, ['en-US', 'en-GB', 'zh-CN', 'ar-SA', 'tr-TR', 'da-DK', 'fi-FI']);
    });

    test('within a language the home-region variant leads', () {
      final tags = ['en-AU', 'en-US', 'en-GB'];
      tags.sort(languageTagCompare);
      expect(tags, ['en-US', 'en-AU', 'en-GB']);
    });

    test('the order is total: sorting any permutation agrees', () {
      final a = ['tr-TR', 'en-US', 'da-DK', 'en-GB', 'zh-CN']..sort(languageTagCompare);
      final b = ['zh-CN', 'en-GB', 'da-DK', 'en-US', 'tr-TR']..sort(languageTagCompare);
      expect(a, b);
    });

    test('a tag compares equal to itself', () {
      expect(languageTagCompare('en-US', 'en-US'), 0);
      expect(languageTagCompare('da-DK', 'da-DK'), 0);
    });
  });
}
