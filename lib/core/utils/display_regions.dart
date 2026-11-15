import 'dart:async';

import 'package:flutter/services.dart';

import 'package:opentranscribe/core/models/display_signal.dart';

/// What the display reserves around the window, read locally over
/// `opentranscribe/display` (see ios/Runner/DisplayRegions.swift). The answer
/// is cached from the event stream, and every failure path reads as
/// [DisplaySignal.unsupported]: a broken monitor must leave today's single
/// column, never a split built on a guess.
class DisplayRegionsMonitor {
  DisplayRegionsMonitor({MethodChannel? methods, EventChannel? events})
    : _methods = methods ?? const MethodChannel('opentranscribe/display'),
      _events = events ?? const EventChannel('opentranscribe/display/events');

  final MethodChannel _methods;
  final EventChannel _events;
  // Sync so [current] and what a listener is handed never disagree, even
  // within the event that changed them.
  final _changes = StreamController<DisplaySignal>.broadcast(sync: true);

  DisplaySignal _current = DisplaySignal.unsupported;

  /// Whether the stream has spoken. Once it has, the detached probe's answer
  /// is the staler of the two and must not overwrite a pushed state.
  bool _sawEvent = false;

  StreamSubscription<Object?>? _sub;

  /// The last settled signal; [DisplaySignal.unsupported] until one arrives.
  DisplaySignal get current => _current;

  /// Each distinct signal after the current one.
  Stream<DisplaySignal> get changes => _changes.stream;

  /// Begins observing. Idempotent, never throws, and costs the launch a
  /// channel listen; the one probe runs detached in case the stream's
  /// opening push was lost.
  void start() {
    if (_sub != null) return;
    _sub = _events.receiveBroadcastStream().listen(
      (wire) {
        _sawEvent = true;
        _set(DisplaySignal.fromWire(wire));
      },
      onError: (Object _) {
        _sawEvent = true;
        _set(null);
      },
    );
    unawaited(_probe());
  }

  Future<void> _probe() async {
    try {
      final wire = await _methods.invokeMethod<Object?>('current');
      if (!_sawEvent) _set(DisplaySignal.fromWire(wire));
    } catch (_) {
      // A missing handler (tests, a torn-down engine) leaves it unsupported.
    }
  }

  void _set(DisplaySignal? signal) {
    final next = signal ?? DisplaySignal.unsupported;
    if (next == _current) return;
    _current = next;
    if (!_changes.isClosed) _changes.add(next);
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    await _changes.close();
  }
}
