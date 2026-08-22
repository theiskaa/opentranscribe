import 'package:flutter/foundation.dart';

/// A purchasable product as a presentation fact: the store's localized price
/// string, never a number the app does math on.
@immutable
final class StoreProduct {
  const StoreProduct({required this.id, required this.displayPrice});

  final String id;

  /// Localized by the store; rendered verbatim, composed nowhere.
  final String displayPrice;

  @override
  bool operator ==(Object other) =>
      other is StoreProduct && other.id == id && other.displayPrice == displayPrice;

  @override
  int get hashCode => Object.hash(id, displayPrice);

  @override
  String toString() => 'StoreProduct($id, $displayPrice)';
}
