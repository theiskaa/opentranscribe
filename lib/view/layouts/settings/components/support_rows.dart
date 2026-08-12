import 'package:flutter/foundation.dart';

import 'package:opentranscribe/core/support/store_product.dart';
import 'package:opentranscribe/core/support/supporter_tier.dart';

/// What a support screen row is, in order of appearance. [buyLifetime]
/// doubles as the upgrade row when the tier is monthly; the view words it by
/// tier, this only decides presence and order.
enum SupportRowKind { buyMonthly, buyLifetime, manage, restore }

@immutable
final class SupportRow {
  const SupportRow(this.kind, [this.product]);

  final SupportRowKind kind;

  /// The product a buy row sells; null on manage and restore.
  final StoreProduct? product;

  @override
  bool operator ==(Object other) =>
      other is SupportRow && other.kind == kind && other.product == product;

  @override
  int get hashCode => Object.hash(kind, product);
}

/// The rows the support screen renders for a tier and a fetch answer, pure so
/// every state is testable without a widget tree.
///
/// A subscription is recognized by carrying a period, never by id, so the
/// view stays as product-name-free as the Swift side. Restore is always
/// present (review requires it, and it is every user's recovery path); buy
/// rows exist only while there is something to sell to this tier; manage
/// exists only for a running subscription. An unreachable store sells
/// nothing even if stale prices were handed in: the unreachable line and a
/// price list must never render together, and this function defends that
/// itself rather than trusting its caller.
List<SupportRow> supportRowsFor({
  required SupporterTier tier,
  required List<StoreProduct>? products,
  required bool storeUnreachable,
}) {
  final sellable = storeUnreachable ? null : products;
  final monthly = sellable?.where((p) => p.period != null).firstOrNull;
  final lifetime = sellable?.where((p) => p.period == null).firstOrNull;
  return [
    if (tier == SupporterTier.none && monthly != null)
      SupportRow(SupportRowKind.buyMonthly, monthly),
    if (tier != SupporterTier.lifetime && lifetime != null)
      SupportRow(SupportRowKind.buyLifetime, lifetime),
    if (tier == SupporterTier.monthly) const SupportRow(SupportRowKind.manage),
    const SupportRow(SupportRowKind.restore),
  ];
}
