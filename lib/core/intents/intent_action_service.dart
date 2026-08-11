import 'dart:async';

import 'package:opentranscribe/core/intents/intent_actions.dart';

/// Turns an action from a system surface into the one thing it means: the
/// recorder, open and recording.
///
/// It navigates and nothing more. Capture is started by the recorder screen
/// itself once its sheet has landed, which is what keeps the microphone round
/// trip off the frames of the transition, so an action that opens the sheet has
/// already done its whole job.
class IntentActionService {
  IntentActionService({
    required this._source,
    required this._canOpenRecorder,
    required this._openRecorder,
  });

  final IntentActions _source;
  final bool Function() _canOpenRecorder;
  final void Function() _openRecorder;

  StreamSubscription<IntentAction>? _subscription;

  /// Begins serving actions, and drains whatever this launch was asked for.
  /// Called once the first frames are on screen: the sheet should rise over a
  /// built journal, not race the frames that build it.
  ///
  /// Subscribing before draining is deliberate. The native side only posts to a
  /// listener that already exists, so a tap landing between the two would
  /// otherwise wait for a resume that may never come.
  Future<void> serve() async {
    _subscription ??= _source.actions.listen(_handle);
    await drain();
  }

  /// Reads any waiting action. Safe to call repeatedly: the native slot clears
  /// on read, and it refuses anything stale.
  ///
  /// Inert before [serve]. A resume can arrive before the first frame has
  /// mounted the router, and draining there would consume the action the
  /// launch was asked for at the one moment nothing can act on it.
  Future<void> drain() async {
    if (_subscription == null) return;
    final action = await _source.takePending();
    if (action == null) return;
    _handle(action);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  void _handle(IntentAction action) {
    switch (action) {
      case IntentAction.startRecording:
        if (!_canOpenRecorder()) return;
        _openRecorder();
    }
  }
}
