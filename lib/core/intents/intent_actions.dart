import 'package:flutter/services.dart';

// Channel identifiers. Must match IntentActions.swift.
const _channel = 'opentranscribe/intents';
const _eventChannel = 'opentranscribe/intents/events';

/// What a system surface asked the recorder to do. The surfaces are the lock
/// screen control and widget row, Control Center, the Action button, Shortcuts
/// and Siri; none of them is named here, because the action is the same
/// whichever one sent it.
enum IntentAction { startRecording }

/// Maps a native action name onto its action, or null for one this build does
/// not know. Unknown names are a version skew between a placed control and the
/// app, so they are dropped rather than raised.
IntentAction? intentActionFromName(String? name) => switch (name) {
  'start' => IntentAction.startRecording,
  _ => null,
};

/// Actions submitted by a system surface.
///
/// Two paths, because a launch and a running app are not the same case. A cold
/// launch lands the action before Dart exists, so it waits and is read with
/// [takePending]. An app already listening is handed the action through
/// [actions]. Both drain the same native slot, which clears on read, so one tap
/// can only ever arrive once.
abstract interface class IntentActions {
  /// Actions that land while the app is running and listening.
  Stream<IntentAction> get actions;

  /// The action this launch or resume was asked for, if any. Reading it clears
  /// it: an action nobody acts on must not fire on some later launch.
  Future<IntentAction?> takePending();
}

/// The [IntentActions] over platform channels.
///
/// Preflight-safe: with no plugin behind it (a non-iOS host, a test harness)
/// [takePending] answers null and [actions] stays silent, so a caller wires this
/// in without guarding.
class PlatformIntentActions implements IntentActions {
  PlatformIntentActions({MethodChannel? methods, EventChannel? events})
    : _methods = methods ?? const MethodChannel(_channel),
      _events = events ?? const EventChannel(_eventChannel) {
    _actions = _events
        .receiveBroadcastStream()
        .map((event) => intentActionFromName(event is String ? event : null))
        .where((action) => action != null)
        .cast<IntentAction>()
        .handleError((Object _) {});
  }

  final MethodChannel _methods;
  final EventChannel _events;
  late final Stream<IntentAction> _actions;

  @override
  Stream<IntentAction> get actions => _actions;

  @override
  Future<IntentAction?> takePending() async {
    try {
      return intentActionFromName(await _methods.invokeMethod<String>('takePending'));
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
