import 'dart:io';

/// A stretch of a recording that holds a voice, in the recording's own time.
typedef VoicedRange = ({Duration start, Duration end});

/// Where a kept recording holds a voice, found on the device from its samples
/// against the recording's own quiet (it works in a noisy room as in a silent
/// one). Only times cross the platform boundary.
abstract interface class AudioActivity {
  /// The voice in [audio] between [start] and [end] (null = the file's own
  /// edge), in file time, ascending and inside those bounds; a slice holding
  /// no frames holds no voice. Never throws. Null when it cannot tell (a
  /// failed probe, or a voice no clearer than the noise around it), so a
  /// caller never loses words to what the probe could not see.
  Future<List<VoicedRange>?> voiced(File audio, {Duration? start, Duration? end});
}
