/// Input level (0..1, native `(dBFS + 60) / 60`) above which a take counts as
/// having heard real sound: digital silence sits near 0, quiet room tone near
/// 0.2, and any spoken word peaks well above this. Set to clear the room floor
/// without ever missing speech: discarding a real take is the failure to avoid.
const double heardLevel = 0.3;

/// How long a take was spoken, measured from the recorder's input level
/// windows rather than assumed from its length: lead-in, pauses and the reach
/// for stop count nothing, so a forecast of the words starts from the talking.
///
/// Every window is one slice of captured audio, as long as the take's median
/// gap between windows: arrival times jitter and burst, and a headset mic's
/// slower rate stretches the slices, but the median follows both. A window is
/// speech at or above the take's own noise floor (its 10th percentile) plus
/// [_lift], and never below [heardLevel]. Quiet runs shorter than [_bridgeUs]
/// between two speech windows are the gaps between words and count as speech.
/// A pause ([markBreak]), a gap over [_breakFactor] slices, or a stamp that
/// runs backwards breaks the bridge; it never erases the windows themselves.
class SpeechTally {
  /// About 9 dB on the recorder's level scale.
  static const double _lift = 0.15;

  static const int _bridgeUs = 300000;
  static const int _breakFactor = 4;

  /// A window's gap when it follows a break rather than another window.
  static const int _afterBreak = -1;

  final List<int> _levels = [];
  final List<int> _gapsUs = [];
  Duration? _last;
  bool _breakNext = true;

  /// Adds the window emitted at [at] (monotonic, since any fixed origin).
  void add(double level, Duration at) {
    final last = _last;
    _last = at;
    final gap = last == null || _breakNext ? _afterBreak : (at - last).inMicroseconds;
    _breakNext = false;
    _levels.add((level.clamp(0.0, 1.0) * 255).round());
    _gapsUs.add(gap < 0 ? _afterBreak : gap);
  }

  /// The capture paused: the next window follows audio nobody recorded.
  void markBreak() => _breakNext = true;

  Duration get speech {
    final slice = _sliceUs();
    if (slice == 0) return Duration.zero;
    final threshold = (_floor() / 255 + _lift).clamp(heardLevel, 1.0) * 255;
    var windows = 0;
    var quiet = 0;
    var afterSpeech = false;
    for (var i = 0; i < _levels.length; i++) {
      final gap = _gapsUs[i];
      if (gap == _afterBreak || gap > slice * _breakFactor) {
        quiet = 0;
        afterSpeech = false;
      }
      if (_levels[i] >= threshold) {
        if (afterSpeech && quiet * slice < _bridgeUs) windows += quiet;
        windows++;
        quiet = 0;
        afterSpeech = true;
      } else if (afterSpeech) {
        quiet++;
      }
    }
    return Duration(microseconds: windows * slice);
  }

  /// The median gap between windows that followed another, or 0 before two did.
  int _sliceUs() {
    final gaps = [
      for (final gap in _gapsUs)
        if (gap > 0) gap,
    ]..sort();
    return gaps.isEmpty ? 0 : gaps[gaps.length ~/ 2];
  }

  /// The 10th percentile level.
  int _floor() {
    final levels = [..._levels]..sort();
    return levels[(levels.length - 1) ~/ 10];
  }
}
