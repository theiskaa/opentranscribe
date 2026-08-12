import 'package:flutter/foundation.dart';

/// A purchasable product as a presentation fact: the store's localized price
/// string, never a number the app does math on.
@immutable
final class StoreProduct {
  const StoreProduct({required this.id, required this.displayPrice, this.period});

  final String id;

  /// Localized by the store; rendered verbatim, composed nowhere.
  final String displayPrice;

  /// The subscription's period unit (`month` today); null for a one-time
  /// product.
  final String? period;

  @override
  bool operator ==(Object other) =>
      other is StoreProduct &&
      other.id == id &&
      other.displayPrice == displayPrice &&
      other.period == period;

  @override
  int get hashCode => Object.hash(id, displayPrice, period);

  @override
  String toString() => 'StoreProduct($id, $displayPrice${period == null ? '' : '/$period'})';
}
