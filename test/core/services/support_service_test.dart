import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/services/support_service.dart';
import 'package:opentranscribe/core/support/store_product.dart';
import 'package:opentranscribe/core/support/support_store.dart';
import 'package:opentranscribe/core/support/supporter_tier.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_support_store.dart';

void main() {
  const key = 'test-encryption-key-0123456789ab';
  const lifetime = 'xyz.opentranscribe.supporter.lifetime';

  late LocalService storage;
  late FakeSupportStore store;
  late SupportService service;

  SupportService rebuild() => SupportService(storage: storage, store: store, lifetimeId: lifetime);

  Future<void> build() async {
    SharedPreferences.setMockInitialValues(const {});
    storage = LocalService();
    await storage.init(legacyKey: key);
    store = FakeSupportStore();
    service = rebuild();
  }

  tearDown(() async {
    service.dispose();
    await store.dispose();
  });

  test('tier answers none on a fresh install without a channel call', () async {
    await build();
    expect(service.tier, SupporterTier.none);
    expect(store.calls, isEmpty);
  });

  test('refresh overwrites the answer when the store answers', () async {
    await build();
    store.entitlementAnswer = SupporterTier.lifetime;
    expect(await service.refresh(), SupporterTier.lifetime);
    expect(service.tier, SupporterTier.lifetime);
  });

  test('refresh keeps the answer when the store throws', () async {
    await build();
    store.entitlementAnswer = SupporterTier.lifetime;
    await service.refresh();
    store.entitlementError = const SupportStoreException(
      'offline',
      SupportStoreException.unavailable,
    );
    expect(await service.refresh(), SupporterTier.lifetime);
    expect(service.tier, SupporterTier.lifetime);
  });

  test('a kept answer survives a rebuild from storage', () async {
    await build();
    store.entitlementAnswer = SupporterTier.lifetime;
    await service.refresh();
    service.dispose();
    await store.dispose();

    store = FakeSupportStore();
    service = rebuild();
    expect(service.tier, SupporterTier.lifetime);
  });

  test('a junk stored value reads as none', () async {
    await build();
    await storage.write('support.tier', 'gold');
    service.dispose();
    service = rebuild();
    expect(service.tier, SupporterTier.none);
  });

  test('a stored retired tier reads as none', () async {
    await build();
    await storage.write('support.tier', 'monthly');
    service.dispose();
    service = rebuild();
    expect(service.tier, SupporterTier.none);
  });

  test('sequential refreshes each ask the store again', () async {
    await build();
    store.entitlementAnswer = SupporterTier.lifetime;
    await service.refresh();
    store.entitlementAnswer = SupporterTier.none;
    expect(await service.refresh(), SupporterTier.none);
    expect(store.calls.where((c) => c == 'entitlement'), hasLength(2));
  });

  test('a refresh-driven change emits on changes', () async {
    await build();
    final emitted = <SupporterTier>[];
    final sub = service.changes.listen(emitted.add);
    store.entitlementAnswer = SupporterTier.lifetime;
    await service.refresh();
    await pumpEventQueue();
    expect(emitted, [SupporterTier.lifetime]);
    await sub.cancel();
  });

  test('a push landing mid-refresh wins over the stale answer', () async {
    await build();
    final gate = Completer<void>();
    store.entitlementGate = gate.future;
    store.entitlementAnswer = SupporterTier.none;
    final refreshing = service.refresh();
    store.push(SupporterTier.lifetime);
    await pumpEventQueue();
    gate.complete();
    expect(await refreshing, SupporterTier.lifetime);
    expect(service.tier, SupporterTier.lifetime);
    expect(storage.readString('support.tier'), 'lifetime');
  });

  test('a purchase during an in-flight refresh still resolves true', () async {
    await build();
    final gate = Completer<void>();
    store.entitlementGate = gate.future;
    store.entitlementAnswer = SupporterTier.none;
    final stale = service.refresh();
    store.purchaseAnswer = PurchaseOutcome.purchased;
    final buying = service.purchase();
    store.entitlementAnswer = SupporterTier.lifetime;
    gate.complete();
    expect(await buying, PurchaseOutcome.purchased);
    expect(service.tier, SupporterTier.lifetime);
    expect(await stale, SupporterTier.none);
  });

  test('a thrown purchase or restore leaves the tier untouched', () async {
    await build();
    store.purchaseError = const SupportStoreException('busy', SupportStoreException.busy);
    await expectLater(service.purchase(), throwsA(isA<SupportStoreException>()));
    store.restoreError = const SupportStoreException('offline', SupportStoreException.unavailable);
    await expectLater(service.restore(), throwsA(isA<SupportStoreException>()));
    expect(service.tier, SupporterTier.none);
    expect(storage.readString('support.tier'), isNull);
  });

  test('dispose during an in-flight refresh is quiet', () async {
    await build();
    final gate = Completer<void>();
    store.entitlementGate = gate.future;
    store.entitlementAnswer = SupporterTier.lifetime;
    final refreshing = service.refresh();
    service.dispose();
    gate.complete();
    expect(await refreshing, SupporterTier.none);
    expect(service.tier, SupporterTier.none);
  });

  test('refresh is single-flight under concurrent calls', () async {
    await build();
    final gate = Completer<void>();
    store.entitlementGate = gate.future;
    store.entitlementAnswer = SupporterTier.lifetime;
    final first = service.refresh();
    final second = service.refresh();
    gate.complete();
    expect(await first, SupporterTier.lifetime);
    expect(await second, SupporterTier.lifetime);
    expect(store.calls.where((c) => c == 'entitlement'), hasLength(1));
  });

  test('a pushed refund flips the tier and emits', () async {
    await build();
    store.entitlementAnswer = SupporterTier.lifetime;
    await service.refresh();

    final emitted = <SupporterTier>[];
    final sub = service.changes.listen(emitted.add);
    store.push(SupporterTier.none);
    await pumpEventQueue();
    expect(service.tier, SupporterTier.none);
    expect(emitted, [SupporterTier.none]);
    await sub.cancel();
  });

  test('a pushed tier matching the cache writes and emits nothing', () async {
    await build();
    final emitted = <SupporterTier>[];
    final sub = service.changes.listen(emitted.add);
    store.push(SupporterTier.none);
    await pumpEventQueue();
    expect(emitted, isEmpty);
    expect(storage.readString('support.tier'), isNull);
    await sub.cancel();
  });

  test('a pushed error is dropped and later pushes still land', () async {
    await build();
    store.pushError(const SupportStoreException('listener died', SupportStoreException.failed));
    await pumpEventQueue();
    store.push(SupporterTier.lifetime);
    await pumpEventQueue();
    expect(service.tier, SupporterTier.lifetime);
  });

  test('a purchased answer refreshes before resolving', () async {
    await build();
    store.purchaseAnswer = PurchaseOutcome.purchased;
    store.entitlementAnswer = SupporterTier.lifetime;
    expect(await service.purchase(), PurchaseOutcome.purchased);
    expect(service.tier, SupporterTier.lifetime);
    expect(store.purchasedIds, [lifetime]);
  });

  test('cancel and pending resolve without a tier change', () async {
    await build();
    store.entitlementAnswer = SupporterTier.lifetime;
    store.purchaseAnswer = PurchaseOutcome.cancelled;
    expect(await service.purchase(), PurchaseOutcome.cancelled);
    store.purchaseAnswer = PurchaseOutcome.pending;
    expect(await service.purchase(), PurchaseOutcome.pending);
    expect(service.tier, SupporterTier.none);
    expect(store.calls.where((c) => c == 'entitlement'), isEmpty);
  });

  test('restore applies the walked answer, including none', () async {
    await build();
    store.entitlementAnswer = SupporterTier.lifetime;
    await service.refresh();
    store.restoreAnswer = SupporterTier.none;
    expect(await service.restore(), SupporterTier.none);
    expect(service.tier, SupporterTier.none);
  });

  test('an unchanged answer does not rewrite storage', () async {
    await build();
    store.entitlementAnswer = SupporterTier.none;
    await service.refresh();
    expect(storage.readString('support.tier'), isNull);
  });

  test('product asks for the lifetime id and answers it', () async {
    await build();
    store.productsAnswer = const [StoreProduct(id: lifetime, displayPrice: r'$24.99')];
    final product = await service.product();
    expect(product.id, lifetime);
    expect(product.displayPrice, r'$24.99');
  });

  test('a store that does not know the product throws instead of answering', () async {
    await build();
    store.productsAnswer = const [];
    await expectLater(
      service.product(),
      throwsA(
        isA<SupportStoreException>().having((e) => e.code, 'code', SupportStoreException.failed),
      ),
    );
  });

  test('the cached price is null until the first product read answers', () async {
    await build();
    expect(service.cachedProduct, isNull);
    store.productsAnswer = const [StoreProduct(id: lifetime, displayPrice: r'$24.99')];
    await service.product();
    expect(service.cachedProduct?.displayPrice, r'$24.99');
  });

  test('warming the price caches it without throwing on a store failure', () async {
    await build();
    store.productsAnswer = const [];
    await service.warmProduct();
    expect(service.cachedProduct, isNull);
    store.productsAnswer = const [StoreProduct(id: lifetime, displayPrice: r'$24.99')];
    await service.warmProduct();
    expect(service.cachedProduct?.id, lifetime);
  });
}
