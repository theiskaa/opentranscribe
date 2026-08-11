import 'dart:async';

import 'package:opentranscribe/core/intents/intent_actions.dart';

/// A stand-in for the native slot and its event channel. Set [pending] to stage
/// what a launch was asked for, call [emit] to push an action at a running app,
/// and read [takeCount] to see how often the slot was asked.
class FakeIntentActions implements IntentActions {
  final _controller = StreamController<IntentAction>.broadcast();

  IntentAction? pending;
  int takeCount = 0;

  @override
  Stream<IntentAction> get actions => _controller.stream;

  @override
  Future<IntentAction?> takePending() async {
    takeCount++;
    final taken = pending;
    pending = null;
    return taken;
  }

  /// Sends [action] and yields, so a listener has run by the time this returns.
  Future<void> emit(IntentAction action) async {
    _controller.add(action);
    await Future<void>.delayed(Duration.zero);
  }

  bool get hasListener => _controller.hasListener;

  Future<void> close() => _controller.close();
}
