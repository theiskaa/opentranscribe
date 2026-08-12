import 'dart:async';

import 'package:opentranscribe/core/support/store_product.dart';
import 'package:opentranscribe/core/support/support_store.dart';
import 'package:opentranscribe/core/support/supporter_tier.dart';

/// In-memory [SupportStore] for service and cubit tests: records calls,
/// answers scripted outcomes, pushes tier changes on demand, never touches a
/// platform channel.
class FakeSupportStore implements SupportStore {
  FakeSupportStore({
    this.productsAnswer = const [],
    this.purchaseAnswer = PurchaseOutcome.purchased,
    this.entitlementAnswer = SupporterTier.none,
    this.restoreAnswer = SupporterTier.none,
  });

  List<StoreProduct> productsAnswer;
  PurchaseOutcome purchaseAnswer;
  SupporterTier entitlementAnswer;
  SupporterTier restoreAnswer;

  SupportStoreException? productsError;
  SupportStoreException? purchaseError;
  SupportStoreException? entitlementError;
  SupportStoreException? restoreError;
  SupportStoreException? manageError;

  /// When set, [entitlement] waits on it before answering, so a test can hold
  /// a refresh in flight.
  Future<void>? entitlementGate;

  final List<String> calls = [];
  final List<String> purchasedIds = [];

  final StreamController<SupporterTier> _pushes = StreamController.broadcast();

  void push(SupporterTier tier) => _pushes.add(tier);

  void pushError(SupportStoreException error) => _pushes.addError(error);

  Future<void> dispose() => _pushes.close();

  @override
  Stream<SupporterTier> get tierChanges => _pushes.stream;

  @override
  Future<List<StoreProduct>> products(List<String> ids) async {
    calls.add('products');
    if (ids.isEmpty) throw ArgumentError.value(ids, 'ids', 'must not be empty');
    final error = productsError;
    if (error != null) throw error;
    return List.of(productsAnswer);
  }

  @override
  Future<PurchaseOutcome> purchase(String id) async {
    calls.add('purchase');
    purchasedIds.add(id);
    final error = purchaseError;
    if (error != null) throw error;
    return purchaseAnswer;
  }

  @override
  Future<SupporterTier> entitlement() async {
    calls.add('entitlement');
    // Captured at call time, like the real walk: an answer changed while a
    // gated call is in flight must not leak into it.
    final answer = entitlementAnswer;
    final gate = entitlementGate;
    if (gate != null) await gate;
    final error = entitlementError;
    if (error != null) throw error;
    return answer;
  }

  @override
  Future<SupporterTier> restore() async {
    calls.add('restore');
    final error = restoreError;
    if (error != null) throw error;
    return restoreAnswer;
  }

  @override
  Future<void> manageSubscriptions() async {
    calls.add('manageSubscriptions');
    final error = manageError;
    if (error != null) throw error;
  }
}
