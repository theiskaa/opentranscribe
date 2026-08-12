import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/services/support_service.dart';
import 'package:opentranscribe/core/support/store_product.dart';
import 'package:opentranscribe/core/support/support_store.dart';
import 'package:opentranscribe/core/support/supporter_tier.dart';

/// How a purchase attempt ended, for the screen's one-shot choreography.
/// Cancel is quiet (the user closed the sheet, nothing to explain);
/// [pending] earns the Ask to Buy line; only [failed] earns a failure sheet.
enum SupportPurchaseResult { purchased, cancelled, pending, failed }

/// How a restore attempt ended. [none] is a sync that walked to no purchase,
/// said plainly; [failed] means the store could not be asked at all.
enum SupportRestoreResult { restored, none, failed }

@immutable
final class SupportState {
  const SupportState({
    required this.tier,
    this.products,
    this.storeUnreachable = false,
    this.purchasingId,
    this.restoring = false,
    this.pendingApproval = false,
  });

  /// The current supporter answer, live: refreshes and transaction pushes
  /// land here without any surface asking.
  final SupporterTier tier;

  /// Null until [SupportCubit.load]'s fetch answers or fails.
  final List<StoreProduct>? products;

  /// The price fetch threw: prices give way to the honest unreachable line,
  /// while the cached [tier] keeps rendering truthfully.
  final bool storeUnreachable;

  /// The product a purchase is presenting for; null when none is.
  final String? purchasingId;

  final bool restoring;

  /// An Ask to Buy purchase answered pending; the quiet line stays until any
  /// tier push lands (whatever it landed as, the wait is over).
  final bool pendingApproval;

  bool get isBusy => purchasingId != null || restoring;

  SupportState copyWith({
    SupporterTier? tier,
    List<StoreProduct>? products,
    bool? storeUnreachable,
    String? purchasingId,
    bool? restoring,
    bool? pendingApproval,
  }) => SupportState(
    tier: tier ?? this.tier,
    products: products ?? this.products,
    storeUnreachable: storeUnreachable ?? this.storeUnreachable,
    purchasingId: purchasingId ?? this.purchasingId,
    restoring: restoring ?? this.restoring,
    pendingApproval: pendingApproval ?? this.pendingApproval,
  );

  SupportState settled() => SupportState(
    tier: tier,
    products: products,
    storeUnreachable: storeUnreachable,
    pendingApproval: pendingApproval,
  );

  @override
  bool operator ==(Object other) =>
      other is SupportState &&
      other.tier == tier &&
      listEquals(other.products, products) &&
      other.storeUnreachable == storeUnreachable &&
      other.purchasingId == purchasingId &&
      other.restoring == restoring &&
      other.pendingApproval == pendingApproval;

  @override
  int get hashCode => Object.hash(
    tier,
    Object.hashAll(products ?? const []),
    storeUnreachable,
    purchasingId,
    restoring,
    pendingApproval,
  );
}

/// Presentation over [SupportService] for the gate surfaces and the support
/// screen: the live tier, the fetched prices, and the one-at-a-time
/// purchase/restore choreography. Business policy stays in the service; this
/// only shapes answers for rendering.
class SupportCubit extends Cubit<SupportState> {
  SupportCubit({required SupportService service})
    : _service = service,
      super(SupportState(tier: service.tier)) {
    // Any tier change also ends an Ask to Buy wait: whatever landed, the
    // answer arrived.
    _changes = _service.changes.listen(
      (tier) => emit(state.copyWith(tier: tier, pendingApproval: false)),
    );
  }

  final SupportService _service;
  late final StreamSubscription<SupporterTier> _changes;

  /// Fetches prices off the build path; the tier is already seeded. A failed
  /// fetch clears any previously fetched prices: the unreachable line and a
  /// price list must never render together.
  Future<void> load() async {
    try {
      final products = await _service.products();
      if (!isClosed) emit(state.copyWith(products: products, storeUnreachable: false));
    } on SupportStoreException {
      if (isClosed) return;
      emit(
        SupportState(
          tier: state.tier,
          storeUnreachable: true,
          purchasingId: state.purchasingId,
          restoring: state.restoring,
        ),
      );
    }
  }

  /// Null when another operation is already running: a double-tap earns
  /// silence, never a wrong sheet. A store already presenting answers
  /// cancelled for the same reason.
  Future<SupportPurchaseResult?> purchase(String id) async {
    if (state.isBusy) return null;
    emit(state.copyWith(purchasingId: id));
    try {
      final outcome = await _service.purchase(id);
      if (outcome == PurchaseOutcome.pending) emit(state.copyWith(pendingApproval: true));
      return switch (outcome) {
        PurchaseOutcome.purchased => SupportPurchaseResult.purchased,
        PurchaseOutcome.cancelled => SupportPurchaseResult.cancelled,
        PurchaseOutcome.pending => SupportPurchaseResult.pending,
      };
    } on SupportStoreException catch (e) {
      return e.code == SupportStoreException.busy
          ? SupportPurchaseResult.cancelled
          : SupportPurchaseResult.failed;
    } finally {
      if (!isClosed) emit(state.settled());
    }
  }

  /// Null only when another operation is already running (double-tap
  /// silence); a store that could not be asked answers [failed] so the
  /// surface never mistakes a failure for a quiet sync.
  Future<SupportRestoreResult?> restore() async {
    if (state.isBusy) return null;
    emit(state.copyWith(restoring: true));
    try {
      final tier = await _service.restore();
      return tier.isSupporter ? SupportRestoreResult.restored : SupportRestoreResult.none;
    } on SupportStoreException {
      return SupportRestoreResult.failed;
    } finally {
      if (!isClosed) emit(state.settled());
    }
  }

  Future<void> manageSubscriptions() async {
    try {
      await _service.manageSubscriptions();
    } on SupportStoreException {
      // The system sheet could not present; nothing to explain.
    }
  }

  @override
  Future<void> close() {
    _changes.cancel();
    return super.close();
  }
}
