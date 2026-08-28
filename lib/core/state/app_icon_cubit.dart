import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/app/app_icon.dart';
import 'package:opentranscribe/core/models/app_icon_descriptor.dart';

/// The picker's answer to a tap, for the surface to word (or ignore).
enum AppIconPickOutcome { switched, unchanged, locked, failed }

@immutable
final class AppIconState {
  const AppIconState({
    required this.options,
    required this.currentId,
    required this.member,
    this.busy = false,
  });

  final List<AppIconDescriptor> options;

  /// The option the OS shows now; the primary icon until [AppIconCubit.load]
  /// has asked.
  final String currentId;

  /// Whether a club icon may be picked now.
  final bool member;

  final bool busy;

  AppIconState copyWith({String? currentId, bool? member, bool? busy}) => AppIconState(
    options: options,
    currentId: currentId ?? this.currentId,
    member: member ?? this.member,
    busy: busy ?? this.busy,
  );
}

/// Drives the icon picker over the registry of shipped icons. The OS is the
/// source of truth for the current icon, so a lapsed entitlement leaves an
/// icon where it is; only picking a club icon is gated.
class AppIconCubit extends Cubit<AppIconState> {
  AppIconCubit({
    required this._store,
    required List<AppIconDescriptor> options,
    bool Function() isSupporter = _never,
    Stream<void>? tierChanges,
  }) : _isSupporter = isSupporter,
       super(
         AppIconState(
           options: options,
           currentId: options.firstWhere((o) => o.iconName == null).id,
           member: isSupporter(),
         ),
       ) {
    _tierSub = tierChanges?.listen((_) {
      if (!isClosed) emit(state.copyWith(member: _isSupporter()));
    }, onError: (Object _) {});
  }

  static bool _never() => false;

  final AppIconStore _store;
  final bool Function() _isSupporter;
  StreamSubscription<void>? _tierSub;

  /// Reads what the OS shows. A failed read keeps the primary icon marked;
  /// the picker must never throw at open.
  Future<void> load() async {
    try {
      final name = await _store.current();
      if (isClosed) return;
      emit(state.copyWith(currentId: _idOf(name)));
    } catch (_) {}
  }

  String _idOf(String? iconName) =>
      state.options.firstWhere((o) => o.iconName == iconName, orElse: () => state.options.first).id;

  Future<AppIconPickOutcome> pick(String id) async {
    if (state.busy) return AppIconPickOutcome.unchanged;
    final option = state.options.firstWhere((o) => o.id == id);
    if (option.club && !state.member) return AppIconPickOutcome.locked;
    if (id == state.currentId) return AppIconPickOutcome.unchanged;
    emit(state.copyWith(busy: true));
    try {
      await _store.set(option.iconName);
      if (isClosed) return AppIconPickOutcome.switched;
      emit(state.copyWith(currentId: id, busy: false));
      return AppIconPickOutcome.switched;
    } catch (_) {
      if (!isClosed) emit(state.copyWith(busy: false));
      return AppIconPickOutcome.failed;
    }
  }

  @override
  Future<void> close() async {
    await _tierSub?.cancel();
    return super.close();
  }
}
