import 'package:flutter_test/flutter_test.dart';

import 'package:opentranscribe/core/support/store_product.dart';
import 'package:opentranscribe/core/support/supporter_tier.dart';
import 'package:opentranscribe/view/layouts/settings/components/support_rows.dart';

void main() {
  const monthly = StoreProduct(id: 'a.monthly', displayPrice: r'$2.99', period: 'month');
  const lifetime = StoreProduct(id: 'a.lifetime', displayPrice: r'$42.00');

  List<SupportRowKind> kindsFor({
    required SupporterTier tier,
    List<StoreProduct>? products,
    bool unreachable = false,
  }) => supportRowsFor(
    tier: tier,
    products: products,
    storeUnreachable: unreachable,
  ).map((r) => r.kind).toList();

  test('a fresh user sees both buys then restore', () {
    expect(kindsFor(tier: SupporterTier.none, products: const [monthly, lifetime]), [
      SupportRowKind.buyMonthly,
      SupportRowKind.buyLifetime,
      SupportRowKind.restore,
    ]);
  });

  test('a subscriber sees the lifetime upgrade, manage, and restore', () {
    expect(kindsFor(tier: SupporterTier.monthly, products: const [monthly, lifetime]), [
      SupportRowKind.buyLifetime,
      SupportRowKind.manage,
      SupportRowKind.restore,
    ]);
  });

  test('a lifetime supporter has nothing for sale, restore stays', () {
    expect(kindsFor(tier: SupporterTier.lifetime, products: const [monthly, lifetime]), [
      SupportRowKind.restore,
    ]);
  });

  test('no fetched prices means no buy rows, whatever the reason', () {
    expect(kindsFor(tier: SupporterTier.none), [SupportRowKind.restore]);
    expect(kindsFor(tier: SupporterTier.none, unreachable: true), [SupportRowKind.restore]);
  });

  test('an unreachable store sells nothing even with stale prices in hand', () {
    expect(
      kindsFor(tier: SupporterTier.none, products: const [monthly, lifetime], unreachable: true),
      [SupportRowKind.restore],
    );
  });

  test('an airplane-mode subscriber still sees manage and restore', () {
    expect(kindsFor(tier: SupporterTier.monthly, unreachable: true), [
      SupportRowKind.manage,
      SupportRowKind.restore,
    ]);
  });

  test('a short store answer renders what arrived, never an invented row', () {
    expect(kindsFor(tier: SupporterTier.none, products: const [lifetime]), [
      SupportRowKind.buyLifetime,
      SupportRowKind.restore,
    ]);
    expect(kindsFor(tier: SupporterTier.none, products: const [monthly]), [
      SupportRowKind.buyMonthly,
      SupportRowKind.restore,
    ]);
  });

  test('buy rows carry their product, manage and restore carry none', () {
    final rows = supportRowsFor(
      tier: SupporterTier.none,
      products: const [monthly, lifetime],
      storeUnreachable: false,
    );
    expect(rows.first.product, monthly);
    expect(rows[1].product, lifetime);
    expect(rows.last.product, isNull);
  });

  test('the subscription is recognized by period, not id or order', () {
    final rows = supportRowsFor(
      tier: SupporterTier.none,
      products: const [lifetime, monthly],
      storeUnreachable: false,
    );
    expect(rows.first.kind, SupportRowKind.buyMonthly);
    expect(rows.first.product, monthly);
  });
}
