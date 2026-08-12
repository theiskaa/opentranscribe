import 'package:flutter_test/flutter_test.dart';

import 'package:opentranscribe/core/support/supporter_tier.dart';

void main() {
  test('parse reads the stored names', () {
    expect(SupporterTier.parse('none'), SupporterTier.none);
    expect(SupporterTier.parse('monthly'), SupporterTier.monthly);
    expect(SupporterTier.parse('lifetime'), SupporterTier.lifetime);
  });

  test('parse falls closed on null, junk, and case drift', () {
    expect(SupporterTier.parse(null), SupporterTier.none);
    expect(SupporterTier.parse(''), SupporterTier.none);
    expect(SupporterTier.parse('supporter'), SupporterTier.none);
    expect(SupporterTier.parse('Monthly'), SupporterTier.none);
    expect(SupporterTier.parse('LIFETIME'), SupporterTier.none);
  });

  test('only none is not a supporter', () {
    expect(SupporterTier.none.isSupporter, isFalse);
    expect(SupporterTier.monthly.isSupporter, isTrue);
    expect(SupporterTier.lifetime.isSupporter, isTrue);
  });
}
