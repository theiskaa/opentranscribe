import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/services/support_service.dart';
import 'package:opentranscribe/core/state/support_cubit.dart';
import 'package:opentranscribe/core/support/store_product.dart';
import 'package:opentranscribe/core/support/support_store.dart';
import 'package:opentranscribe/core/support/supporter_tier.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_support_store.dart';

void main() {
  const lifetime = 'xyz.opentranscribe.supporter.lifetime';
  const product = StoreProduct(id: lifetime, displayPrice: r'$24.99');

  late FakeSupportStore store;
  late SupportService service;
  late SupportCubit cubit;

  Future<void> build() async {
    SharedPreferences.setMockInitialValues(const {});
    final storage = LocalService();
    await storage.init(legacyKey: 'test-encryption-key-0123456789ab');
    store = FakeSupportStore(productsAnswer: const [product]);
    service = SupportService(storage: storage, store: store, lifetimeId: lifetime);
    cubit = SupportCubit(service: service);
  }

  tearDown(() async {
    await cubit.close();
    service.dispose();
    await store.dispose();
  });

  test('seeds from the service and load answers the price', () async {
    await build();
    expect(cubit.state.tier, SupporterTier.none);
    expect(cubit.state.product, isNull);
    await cubit.load();
    expect(cubit.state.product, product);
    expect(cubit.state.storeUnreachable, isFalse);
  });

  test('seeds the price from the service cache so the button needs no round trip', () async {
    await build();
    await service.warmProduct();
    final warmed = SupportCubit(service: service);
    expect(warmed.state.product, product);
    await warmed.close();
  });

  test('an unreachable store flags honestly and keeps the tier', () async {
    await build();
    store.productsError = const SupportStoreException('offline', SupportStoreException.unavailable);
    await cubit.load();
    expect(cubit.state.product, isNull);
    expect(cubit.state.storeUnreachable, isTrue);
    expect(cubit.state.tier, SupporterTier.none);
  });

  test('a store that lost the product flags unreachable, not a broken buy', () async {
    await build();
    store.productsAnswer = const [];
    await cubit.load();
    expect(cubit.state.product, isNull);
    expect(cubit.state.storeUnreachable, isTrue);
  });

  test('a service push lands in the state without asking', () async {
    await build();
    store.push(SupporterTier.lifetime);
    await pumpEventQueue();
    expect(cubit.state.tier, SupporterTier.lifetime);
  });

  test('a purchase busies the state and settles after', () async {
    await build();
    store.purchaseAnswer = PurchaseOutcome.purchased;
    store.entitlementAnswer = SupporterTier.lifetime;
    final running = cubit.purchase();
    expect(cubit.state.purchasing, isTrue);
    expect(await running, SupportPurchaseResult.purchased);
    expect(cubit.state.purchasing, isFalse);
    expect(cubit.state.tier, SupporterTier.lifetime);
  });

  test('cancel and pending come back as their own outcomes', () async {
    await build();
    store.purchaseAnswer = PurchaseOutcome.cancelled;
    expect(await cubit.purchase(), SupportPurchaseResult.cancelled);
    store.purchaseAnswer = PurchaseOutcome.pending;
    expect(await cubit.purchase(), SupportPurchaseResult.pending);
    expect(cubit.state.tier, SupporterTier.none);
  });

  test('a thrown purchase answers failed, a busy store answers cancelled', () async {
    await build();
    store.purchaseError = const SupportStoreException('broke', SupportStoreException.failed);
    expect(await cubit.purchase(), SupportPurchaseResult.failed);
    store.purchaseError = const SupportStoreException('presenting', SupportStoreException.busy);
    expect(await cubit.purchase(), SupportPurchaseResult.cancelled);
    expect(cubit.state.isBusy, isFalse);
  });

  test('a second operation while one runs earns silence', () async {
    await build();
    final gate = Completer<void>();
    store.entitlementGate = gate.future;
    store.purchaseAnswer = PurchaseOutcome.purchased;
    final first = cubit.purchase();
    expect(await cubit.purchase(), isNull);
    expect(await cubit.restore(), isNull);
    gate.complete();
    await first;
    expect(store.purchasedIds, [lifetime]);
  });

  test('restore says plainly whether a purchase was found', () async {
    await build();
    store.restoreAnswer = SupporterTier.none;
    expect(await cubit.restore(), SupportRestoreResult.none);
    store.restoreAnswer = SupporterTier.lifetime;
    expect(await cubit.restore(), SupportRestoreResult.restored);
    expect(cubit.state.tier, SupporterTier.lifetime);
    expect(cubit.state.restoring, isFalse);
  });

  test('a thrown restore answers failed, never silence', () async {
    await build();
    store.restoreError = const SupportStoreException('offline', SupportStoreException.failed);
    expect(await cubit.restore(), SupportRestoreResult.failed);
    expect(cubit.state.isBusy, isFalse);
  });

  test('a failed load keeps an Ask to Buy wait standing', () async {
    await build();
    store.purchaseAnswer = PurchaseOutcome.pending;
    await cubit.purchase();
    store.productsError = const SupportStoreException('offline', SupportStoreException.unavailable);
    await cubit.load();
    expect(cubit.state.pendingApproval, isTrue);
    expect(cubit.state.storeUnreachable, isTrue);
  });

  test('a pending purchase raises the wait and a tier push ends it', () async {
    await build();
    store.purchaseAnswer = PurchaseOutcome.pending;
    expect(await cubit.purchase(), SupportPurchaseResult.pending);
    expect(cubit.state.pendingApproval, isTrue);
    expect(cubit.state.isBusy, isFalse);
    store.push(SupporterTier.lifetime);
    await pumpEventQueue();
    expect(cubit.state.pendingApproval, isFalse);
    expect(cubit.state.tier, SupporterTier.lifetime);
  });
}
