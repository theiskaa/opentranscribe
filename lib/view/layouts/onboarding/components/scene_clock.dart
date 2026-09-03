import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// A clock for a showcase scene: it runs once from zero to [length] and stops
/// there. A scene derives its whole state from [elapsed], so it is a pure
/// function of time and needs no cue list. Under Reduce Motion the clock parks
/// at [length], the resting frame, and never ticks.
class SceneClock extends ChangeNotifier {
  SceneClock({required this.length, required TickerProvider vsync, required bool reduceMotion})
    : _elapsed = reduceMotion ? length : Duration.zero {
    if (reduceMotion) return;
    _ticker = vsync.createTicker((t) {
      if (t >= length) {
        _elapsed = length;
        _ticker?.stop();
      } else {
        _elapsed = t;
      }
      notifyListeners();
    })..start();
  }

  final Duration length;
  Ticker? _ticker;
  Duration _elapsed;

  Duration get elapsed => _elapsed;

  @override
  void dispose() {
    _ticker?.dispose();
    super.dispose();
  }
}
