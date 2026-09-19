/// Input level (0..1, native `(dBFS + 60) / 60`) above which a take counts as
/// having heard real sound: digital silence sits near 0, quiet room tone near
/// 0.2, and any spoken word peaks well above this. Set to clear the room floor
/// without ever missing speech: discarding a real take is the failure to avoid.
const double heardLevel = 0.3;

/// How long a take was spoken, from the recorder's input level windows: each
/// stretch of speech from its first word to its last, the breaths and pauses
/// between words included, while the lead-in, the reach for stop and any
/// silence of [_pauseLimit] or more count nothing.
///
/// Counted in windows, never timed by their arrival: every window stands for
/// the same slice of captured audio whatever the mic's rate or however its
/// delivery bunched, so a take's length over its window count is that slice.
/// A window is speech at or above the take's own noise floor (its 10th
/// percentile) plus [_lift], and never below [heardLevel]. A pause
/// ([markBreak]) ends the stretch before it.
class SpeechTally {
  /// About 9 dB on the recorder's level scale.
  static const double _lift = 0.15;

  static const Duration _pauseLimit = Duration(seconds: 2);

  final List<int> _levels = [];
  final Set<int> _breaks = {};

  void add(double level) => _levels.add((level.clamp(0.0, 1.0) * 255).round());

  /// The capture paused: the next window follows audio nobody recorded.
  void markBreak() => _breaks.add(_levels.length);

  /// The speech in [audio], the length of the take these windows covered.
  Duration speechOf(Duration audio) {
    if (_levels.isEmpty || audio <= Duration.zero) return Duration.zero;
    final sliceUs = audio.inMicroseconds / _levels.length;
    final threshold = (_floor() / 255 + _lift).clamp(heardLevel, 1.0) * 255;
    var windows = 0;
    var quiet = 0;
    var talking = false;
    for (var i = 0; i < _levels.length; i++) {
      if (_breaks.contains(i)) {
        quiet = 0;
        talking = false;
      }
      if (_levels[i] >= threshold) {
        if (talking && quiet * sliceUs < _pauseLimit.inMicroseconds) windows += quiet;
        windows++;
        quiet = 0;
        talking = true;
      } else if (talking) {
        quiet++;
      }
    }
    return Duration(microseconds: (windows * sliceUs).round());
  }

  /// The 10th percentile level.
  int _floor() {
    final levels = [..._levels]..sort();
    return levels[(levels.length - 1) ~/ 10];
  }
}
