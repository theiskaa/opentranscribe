import 'package:flutter/services.dart';

import 'package:opentranscribe/core/support/store_product.dart';
import 'package:opentranscribe/core/support/supporter_tier.dart';

// Channel identifiers. Must match SupportStore.swift.
const _methodsChannel = 'opentranscribe/support';
const _eventsChannel = 'opentranscribe/support/events';

/// What a purchase call resolved to. A user decision is an outcome here,
/// never an exception: [cancelled] is the sheet dismissed, [pending] is a
/// purchase awaiting Ask to Buy approval, which lands (or not) later on
/// [SupportStore.tierChanges].
enum PurchaseOutcome { purchased, cancelled, pending }

/// The app's one door to StoreKit, over `SupportStore.swift`. Talks prices
/// and entitlements, never journal content; presenting a purchase flow is
/// always the direct result of a user tap.
///
/// Tier answers are fail-closed: a missing or unknown value reads as
/// [SupporterTier.none], so a bad reply can lock but never grant.
/// [SupportStoreException] means a call could not run or a reply could not
/// be read; a user cancel is never an exception.
class SupportStore {
  SupportStore({MethodChannel? methods, EventChannel? events})
    : _methods = methods ?? const MethodChannel(_methodsChannel) {
    _tierChanges = (events ?? const EventChannel(_eventsChannel))
        .receiveBroadcastStream()
        .handleError(_rethrowMapped, test: (error) => error is PlatformException)
        .map(_tierOf);
  }

  final MethodChannel _methods;
  late final Stream<SupporterTier> _tierChanges;

  /// The recomputed tier, pushed whenever native's transaction listener sees
  /// a verified change: a renewal, a refund, a revocation, an Ask to Buy
  /// approval, a purchase on another device.
  Stream<SupporterTier> get tierChanges => _tierChanges;

  /// The purchasable [ids] as localized presentation facts. Needs the store
  /// reachable: this throws rather than answers a stale price.
  Future<List<StoreProduct>> products(List<String> ids) async {
    if (ids.isEmpty) throw ArgumentError.value(ids, 'ids', 'must not be empty');
    final reply = await _invoke<List<Object?>>('products', {'ids': ids});
    if (reply == null) {
      throw const SupportStoreException('malformed products reply', SupportStoreException.failed);
    }
    return [for (final item in reply) _productOf(item)];
  }

  /// Presents the purchase sheet for [id]; the user's decision comes back as
  /// an outcome, never an exception.
  Future<PurchaseOutcome> purchase(String id) async {
    final reply = await _invoke<Map<Object?, Object?>>('purchase', {'id': id});
    return switch (reply?['outcome']) {
      'purchased' => PurchaseOutcome.purchased,
      'cancelled' => PurchaseOutcome.cancelled,
      'pending' => PurchaseOutcome.pending,
      _ => throw const SupportStoreException(
        'malformed purchase reply',
        SupportStoreException.failed,
      ),
    };
  }

  /// The tier StoreKit currently answers for, from its own on-device record
  /// of verified transactions. Local; answers in airplane mode.
  Future<SupporterTier> entitlement() async =>
      _tierOf(await _invoke<Map<Object?, Object?>>('entitlement'));

  /// Syncs purchases with the store (the restore action), then answers the
  /// walked tier. Needs network; a failure here changes nothing.
  Future<SupporterTier> restore() async => _tierOf(await _invoke<Map<Object?, Object?>>('restore'));

  /// Presents the system manage-subscriptions sheet; resolves once it closes.
  Future<void> manageSubscriptions() => _invoke<void>('manageSubscriptions');

  Future<T?> _invoke<T>(String method, [Object? args]) async {
    try {
      return await _methods.invokeMethod<T>(method, args);
    } on PlatformException catch (e) {
      throw SupportStoreException(e.message, e.code);
    } on MissingPluginException catch (e) {
      throw SupportStoreException(e.message);
    } on TypeError {
      // invokeMethod's own cast: a wrong-shaped container is a malformed
      // reply, not an Error, so callers keep one failure type.
      throw const SupportStoreException('malformed reply', SupportStoreException.failed);
    }
  }

  static StoreProduct _productOf(Object? raw) {
    final map = raw is Map ? raw : null;
    final id = map?['id'];
    final price = map?['displayPrice'];
    final period = map?['period'];
    if (id is! String || price is! String || period is! String?) {
      throw const SupportStoreException('malformed product reply', SupportStoreException.failed);
    }
    return StoreProduct(id: id, displayPrice: price, period: period);
  }

  static SupporterTier _tierOf(Object? raw) {
    final tier = raw is Map ? raw['tier'] : null;
    return SupporterTier.parse(tier is String ? tier : null);
  }

  static Never _rethrowMapped(Object error) {
    final e = error as PlatformException;
    throw SupportStoreException(e.message, e.code);
  }
}

/// Thrown when a store call could not run or a reply could not be read; a
/// user cancel is never an exception.
class SupportStoreException implements Exception {
  const SupportStoreException(this.message, [this.code]);

  static const unavailable = 'unavailable';
  static const busy = 'busy';
  static const unverified = 'unverified';
  static const failed = 'failed';

  final String? message;
  final String? code;

  @override
  String toString() => 'SupportStoreException(${code ?? 'no code'}): ${message ?? 'no message'}';
}
