import 'dart:async';

import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/support/store_product.dart';
import 'package:opentranscribe/core/support/support_store.dart';
import 'package:opentranscribe/core/support/supporter_tier.dart';

/// The one owner of the supporter answer.
///
/// [tier] is synchronous and channel-free, so launch and the export guard
/// never wait on StoreKit. The store's answer wins whenever a query succeeds;
/// a thrown query keeps the current answer, so being offline can never take a
/// paying user's entitlement away. Pushes from the store's transaction
/// listener land the same way, so a refund, a renewal, or an Ask to Buy
/// approval needs no surface to ask.
class SupportService {
  SupportService({required this._storage, required this._store, required this._lifetimeId}) {
    // Errors are dropped, not just ignored: the stream stays alive after one,
    // and the tier simply stands until a readable push or refresh arrives.
    _pushes = _store.tierChanges.listen(_apply, onError: (Object _) {});
  }

  static const _tierKey = 'support.tier';

  final LocalService _storage;
  final SupportStore _store;
  final String _lifetimeId;

  final StreamController<SupporterTier> _changes = StreamController.broadcast();
  late final StreamSubscription<SupporterTier> _pushes;
  Future<SupporterTier>? _refreshing;

  /// The last price a [product] call read, kept for the session so a surface
  /// opening after launch can render the join button at once instead of
  /// waiting on a fresh round trip. Null until the first fetch answers.
  StoreProduct? _cachedProduct;

  /// Bumped on every applied change, so an answer computed before a push
  /// landed can see it is stale and stand down instead of overwriting.
  int _epoch = 0;

  /// In-memory truth for the session, seeded from storage once; storage only
  /// bridges launches, so an emitted change and a [tier] read never disagree.
  late SupporterTier _tier = _readStored();

  /// The current tier. Never a channel call; a bad stored value reads as
  /// [SupporterTier.none] like every settings read.
  SupporterTier get tier => _tier;

  /// The last read price, or null before any [product] call has answered. A
  /// surface seeds its first frame from this so the button need not wait on a
  /// round trip; [product] still refreshes it.
  StoreProduct? get cachedProduct => _cachedProduct;

  /// Warms [cachedProduct] off the launch path, swallowing failure: an unwarmed
  /// price just falls back to the surface's own fetch.
  Future<void> warmProduct() async {
    try {
      await product();
    } catch (_) {}
  }

  /// Emits on every change of [tier]. No replay for a new listener; pair
  /// with [tier] for the current answer.
  Stream<SupporterTier> get changes => _changes.stream;

  /// Asks the store and applies its answer. Single-flight: concurrent calls
  /// share one round trip. A thrown query answers the kept [tier].
  Future<SupporterTier> refresh() =>
      _refreshing ??= _refresh().whenComplete(() => _refreshing = null);

  /// The lifetime unlock as a localized presentation fact. Needs the store
  /// reachable; throws rather than answers a stale price, including when the
  /// store answers but does not know the product.
  Future<StoreProduct> product() async {
    final products = await _store.products([_lifetimeId]);
    if (products.isEmpty) {
      throw const SupportStoreException('product not in the store', SupportStoreException.failed);
    }
    return _cachedProduct = products.first;
  }

  /// Presents the purchase sheet for the lifetime unlock. A purchased answer
  /// applies the store's recomputed tier before resolving, so the caller's
  /// next [tier] read is already true; pending resolves unchanged and lands
  /// later as a push, cancel is silence.
  Future<PurchaseOutcome> purchase() async {
    final outcome = await _store.purchase(_lifetimeId);
    if (outcome == PurchaseOutcome.purchased) {
      // Drain a round trip already in flight first: it was issued before the
      // purchase, so joining it would resolve against the pre-purchase truth.
      final stale = _refreshing;
      if (stale != null) await stale.catchError((_) => _tier);
      try {
        await refresh();
      } catch (_) {
        // A purchased answer must resolve as purchased; the transaction
        // listener heals the tier if this refresh failed unexpectedly.
      }
    }
    return outcome;
  }

  /// Syncs purchases with the store and applies the walked tier, including
  /// [SupporterTier.none]: restore answers what the store knows, it does not
  /// only ever upgrade.
  Future<SupporterTier> restore() async {
    final epoch = _epoch;
    final answer = await _store.restore();
    if (_epoch != epoch) return _tier;
    await _apply(answer);
    return answer;
  }

  Future<SupporterTier> _refresh() async {
    final epoch = _epoch;
    final SupporterTier answer;
    try {
      answer = await _store.entitlement();
    } on SupportStoreException {
      return _tier;
    }
    // A push that landed mid-flight is newer truth than an answer computed
    // before it: stand down rather than overwrite.
    if (_epoch != epoch || _changes.isClosed) return _tier;
    await _apply(answer);
    return answer;
  }

  Future<void> _apply(SupporterTier answer) async {
    if (_changes.isClosed) return;
    if (answer == _tier) return;
    _epoch++;
    _tier = answer;
    _changes.add(answer);
    try {
      await _storage.write(_tierKey, answer.name);
    } catch (_) {
      // Stale storage costs one launch's answer; the maintenance refresh
      // rewrites it.
    }
  }

  SupporterTier _readStored() {
    try {
      return SupporterTier.parse(_storage.readString(_tierKey));
    } catch (_) {
      return SupporterTier.none;
    }
  }

  void dispose() {
    _pushes.cancel();
    _changes.close();
  }
}
