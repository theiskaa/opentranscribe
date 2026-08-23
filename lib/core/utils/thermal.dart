import 'dart:async';

import 'package:flutter/services.dart';

/// The device's thermal pressure, read locally over `opentranscribe/thermal`
/// (see ios/Runner/ThermalMonitor.swift). The answer is CACHED from the event
/// stream, so a between-entries check costs no channel round trip, and every
/// failure path reads as no pressure: a broken probe must never be what
/// pauses bulk work forever.
class ThermalMonitor {
  ThermalMonitor({MethodChannel? methods, EventChannel? events})
    : _methods = methods ?? const MethodChannel('opentranscribe/thermal'),
      _events = events ?? const EventChannel('opentranscribe/thermal/events');

  final MethodChannel _methods;
  final EventChannel _events;

  bool _underPressure = false;

  /// Whether the stream has spoken. Once it has, the detached probe's answer
  /// is the staler of the two and must not overwrite a pushed state.
  bool _sawEvent = false;

  StreamSubscription<Object?>? _sub;

  /// Whether the device is running hot (serious or critical). The bulk
  /// re-transcribe queue holds between entries while this is true.
  bool get underPressure => _underPressure;

  static bool _pressured(Object? state) => state == 'serious' || state == 'critical';

  /// Begins observing. Idempotent, never throws, and costs the launch
  /// nothing: the subscription is a channel listen, and the one probe runs
  /// detached in case the stream's opening push was lost.
  void start() {
    if (_sub != null) return;
    _sub = _events.receiveBroadcastStream().listen(
      (state) {
        _sawEvent = true;
        _underPressure = _pressured(state);
      },
      onError: (Object _) {
        _sawEvent = true;
        _underPressure = false;
      },
    );
    unawaited(_probe());
  }

  Future<void> _probe() async {
    try {
      final pressured = _pressured(await _methods.invokeMethod<String>('state'));
      if (!_sawEvent) _underPressure = pressured;
    } catch (_) {
      // A missing handler (tests, a torn-down engine) reads as no pressure.
    }
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }
}
