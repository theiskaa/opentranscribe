import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opentranscribe/core/support/store_product.dart';
import 'package:opentranscribe/core/support/support_store.dart';
import 'package:opentranscribe/core/support/supporter_tier.dart';

/// Pins the channel contract with SupportStore.swift: payload shapes, outcome
/// strings, fail-closed tier reads, error-code mapping.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const methods = MethodChannel('opentranscribe/support');
  const events = EventChannel('opentranscribe/support/events');

  tearDown(() {
    messenger.setMockMethodCallHandler(methods, null);
    messenger.setMockStreamHandler(events, null);
  });

  test('products sends the ids and maps the replies', () async {
    late MethodCall seen;
    messenger.setMockMethodCallHandler(methods, (call) async {
      seen = call;
      return [
        {'id': 'a.lifetime', 'displayPrice': r'$24.99'},
      ];
    });
    expect(await SupportStore().products(['a.lifetime']), const [
      StoreProduct(id: 'a.lifetime', displayPrice: r'$24.99'),
    ]);
    expect(seen.method, 'products');
    expect(seen.arguments, {
      'ids': ['a.lifetime'],
    });
  });

  test('a product reply missing its price is refused, not guessed', () async {
    messenger.setMockMethodCallHandler(methods, (call) async {
      return [
        {'id': 'a.lifetime'},
      ];
    });
    await expectLater(
      SupportStore().products(['a.lifetime']),
      throwsA(isA<SupportStoreException>()),
    );
  });

  test('an empty id list is refused before the channel', () {
    var called = false;
    messenger.setMockMethodCallHandler(methods, (call) async {
      called = true;
      return const <Object?>[];
    });
    expect(() => SupportStore().products([]), throwsArgumentError);
    expect(called, isFalse);
  });

  test('a null products reply is refused, not an empty catalogue', () async {
    messenger.setMockMethodCallHandler(methods, (call) async => null);
    await expectLater(
      SupportStore().products(['a.lifetime']),
      throwsA(
        isA<SupportStoreException>().having((e) => e.code, 'code', SupportStoreException.failed),
      ),
    );
  });

  test('a wrong-shaped top-level reply folds to the domain exception', () async {
    messenger.setMockMethodCallHandler(methods, (call) async => 'lifetime');
    await expectLater(
      SupportStore().entitlement(),
      throwsA(
        isA<SupportStoreException>().having((e) => e.code, 'code', SupportStoreException.failed),
      ),
    );

    messenger.setMockMethodCallHandler(methods, (call) async => {'id': 'a.lifetime'});
    await expectLater(
      SupportStore().products(['a.lifetime']),
      throwsA(isA<SupportStoreException>()),
    );

    messenger.setMockMethodCallHandler(methods, (call) async => const <Object?>[]);
    await expectLater(SupportStore().purchase('a.lifetime'), throwsA(isA<SupportStoreException>()));
  });

  test('a cancelled purchase is an outcome, not an error', () async {
    messenger.setMockMethodCallHandler(methods, (call) async {
      expect(call.method, 'purchase');
      expect((call.arguments as Map)['id'], 'a.lifetime');
      return {'outcome': 'cancelled'};
    });
    expect(await SupportStore().purchase('a.lifetime'), PurchaseOutcome.cancelled);
  });

  test('purchased and pending map to their outcomes', () async {
    messenger.setMockMethodCallHandler(methods, (call) async => {'outcome': 'purchased'});
    expect(await SupportStore().purchase('a.lifetime'), PurchaseOutcome.purchased);
    messenger.setMockMethodCallHandler(methods, (call) async => {'outcome': 'pending'});
    expect(await SupportStore().purchase('a.lifetime'), PurchaseOutcome.pending);
  });

  test('an unknown purchase outcome is refused, not guessed', () async {
    messenger.setMockMethodCallHandler(methods, (call) async => {'outcome': 'refunded'});
    await expectLater(
      SupportStore().purchase('a.lifetime'),
      throwsA(
        isA<SupportStoreException>().having((e) => e.code, 'code', SupportStoreException.failed),
      ),
    );
  });

  test('entitlement reads the tier and falls closed on junk', () async {
    messenger.setMockMethodCallHandler(methods, (call) async {
      expect(call.method, 'entitlement');
      return {'tier': 'lifetime'};
    });
    expect(await SupportStore().entitlement(), SupporterTier.lifetime);

    messenger.setMockMethodCallHandler(methods, (call) async => {'tier': 'gold'});
    expect(await SupportStore().entitlement(), SupporterTier.none);

    messenger.setMockMethodCallHandler(methods, (call) async => null);
    expect(await SupportStore().entitlement(), SupporterTier.none);
  });

  test('a platform error surfaces with its code preserved', () async {
    messenger.setMockMethodCallHandler(methods, (call) async {
      throw PlatformException(code: 'unavailable', message: 'store unreachable');
    });
    await expectLater(
      SupportStore().entitlement(),
      throwsA(
        isA<SupportStoreException>().having(
          (e) => e.code,
          'code',
          SupportStoreException.unavailable,
        ),
      ),
    );
  });

  test('restore answers the walked tier after the sync', () async {
    messenger.setMockMethodCallHandler(methods, (call) async {
      expect(call.method, 'restore');
      return {'tier': 'lifetime'};
    });
    expect(await SupportStore().restore(), SupporterTier.lifetime);
  });

  test('tier pushes parse and junk falls closed to none', () async {
    messenger.setMockStreamHandler(
      events,
      MockStreamHandler.inline(
        onListen: (arguments, sink) {
          sink.success({'tier': 'none'});
          sink.success({'tier': 'gold'});
          sink.success('junk');
          sink.success({'tier': 'lifetime'});
        },
      ),
    );
    expect(await SupportStore().tierChanges.take(4).toList(), const [
      SupporterTier.none,
      SupporterTier.none,
      SupporterTier.none,
      SupporterTier.lifetime,
    ]);
  });

  test('a stream error surfaces as the domain exception', () async {
    messenger.setMockStreamHandler(
      events,
      MockStreamHandler.inline(
        onListen: (arguments, sink) {
          sink.error(code: 'failed', message: 'listener died');
        },
      ),
    );
    await expectLater(
      SupportStore().tierChanges.first,
      throwsA(
        isA<SupportStoreException>().having((e) => e.code, 'code', SupportStoreException.failed),
      ),
    );
  });

  test('a missing plugin surfaces as the domain exception', () async {
    await expectLater(SupportStore().entitlement(), throwsA(isA<SupportStoreException>()));
  });
}
