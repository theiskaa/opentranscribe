import 'dart:async' show StreamSubscription;

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
    this.currentId,
    this.member = false,
    this.busy = false,
  });

  final List<AppIconDescriptor> options;

  /// The option the OS shows now; null until the OS has answered, so an
  /// unread icon never swallows a tap as unchanged.
  final String? currentId;

  /// Whether the supporter tier says member, which is what a club icon needs.
  final bool member;

  final bool busy;

  AppIconState copyWith({String? currentId, bool? member, bool? busy}) => AppIconState(
    options: options,
    currentId: currentId ?? this.currentId,
    member: member ?? this.member,
    busy: busy ?? this.busy,
  );
}

/// Drives the icon picker over the shipped icons. The OS is the source of
/// truth for the current one: a landed pick outranks a read started before it.
/// A club icon needs a membership; a lapsed one leaves the worn icon where it
/// is, since only the OS can change that and nothing here asks it to.
class AppIconCubit extends Cubit<AppIconState> {
  AppIconCubit({
    required this._store,
    required List<AppIconDescriptor> options,
    bool Function() isSupporter = _never,
    Stream<void>? tierChanges,
  }) : _isSupporter = isSupporter,
       super(AppIconState(options: options, member: isSupporter())) {
    _tierSub = tierChanges?.listen((_) {
      if (!isClosed) emit(state.copyWith(member: _isSupporter()));
    }, onError: (Object _) {});
  }

  static bool _never() => false;

  final AppIconStore _store;
  final bool Function() _isSupporter;
  StreamSubscription<void>? _tierSub;
  bool _picked = false;

  /// Reads what the OS shows. A failed read leaves the icon unknown; the
  /// picker must never throw at open.
  Future<void> load() async {
    try {
      final name = await _store.current();
      if (isClosed || _picked) return;
      emit(state.copyWith(currentId: _idOf(name)));
    } catch (_) {}
  }

  String _idOf(String? iconName) => state.options
      .firstWhere(
        (o) => o.iconName == iconName,
        orElse: () => state.options.firstWhere((o) => o.iconName == null),
      )
      .id;

  Future<AppIconPickOutcome> pick(String id) async {
    if (state.busy || id == state.currentId) return AppIconPickOutcome.unchanged;
    final option = state.options.firstWhere((o) => o.id == id);
    if (option.club && !state.member) return AppIconPickOutcome.locked;
    emit(state.copyWith(busy: true));
    try {
      await _store.set(option.iconName);
      _picked = true;
      if (isClosed) return AppIconPickOutcome.switched;
      emit(state.copyWith(currentId: id, busy: false));
      return AppIconPickOutcome.switched;
    } catch (e) {
      if (kDebugMode) debugPrint('app icon refused: $e');
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
