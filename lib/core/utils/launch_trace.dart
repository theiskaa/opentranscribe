import 'package:flutter/foundation.dart';

/// TEMP launch instrumentation. Records how long each startup phase takes and
/// prints one table once home is on screen. Debug and profile only; a release
/// build records nothing and prints nothing.
///
/// Read it in profile (`flutter run --profile`): a debug build runs the Dart
/// phases under the JIT, which inflates them past anything a user would see.
abstract final class LaunchTrace {
  static final Stopwatch _clock = Stopwatch();
  static final List<(String, int)> _marks = [];
  static int _epochMs = 0;

  /// Called first thing in `main`, so every mark is measured from the earliest
  /// moment Dart can observe. Everything before it (dyld, the engine, the first
  /// native frame) is outside this clock; the wall-clock stamp the dump prints
  /// is what lines the table up against the process start in the device log.
  static void start() {
    if (kReleaseMode) return;
    _epochMs = DateTime.now().millisecondsSinceEpoch;
    // A hot restart re-runs main with marks still queued from a launch whose
    // dump never ran; keeping them would print deltas against a reset clock.
    _marks.clear();
    _clock
      ..reset()
      ..start();
  }

  static void mark(String label) {
    if (kReleaseMode || !_clock.isRunning) return;
    _marks.add((label, _clock.elapsedMilliseconds));
  }

  static void dump() {
    if (kReleaseMode || _marks.isEmpty) return;
    final buffer = StringBuffer('launch trace: dart main at epoch $_epochMs\n');
    var previous = 0;
    for (final (label, at) in _marks) {
      final took = (at - previous).toString().padLeft(5);
      buffer.writeln('  ${label.padRight(20)} $took ms   (+$at)');
      previous = at;
    }
    // Since main, not since launch: whatever ran before Dart (dyld, the
    // engine, the first native frame) is outside this clock entirely.
    buffer.write('  ${'since main'.padRight(20)} ${previous.toString().padLeft(5)} ms');
    debugPrint(buffer.toString());
    _marks.clear();
    _clock.stop();
  }
}
