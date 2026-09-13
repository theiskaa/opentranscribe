import 'dart:io';

import 'package:transcriber/src/audio/audio_activity.dart';

/// Deterministic [AudioActivity] for tests: answers [ranges] clipped to each
/// question's bounds (null answers null, as a probe that cannot tell), and
/// records every question in [calls].
class FakeAudioActivity implements AudioActivity {
  FakeAudioActivity({this.ranges = const []});

  /// The voice in the whole recording, in file time; mutable between calls.
  List<VoicedRange>? ranges;

  final List<({String path, Duration? start, Duration? end})> calls = [];

  @override
  Future<List<VoicedRange>?> voiced(File audio, {Duration? start, Duration? end}) async {
    calls.add((path: audio.path, start: start, end: end));
    final all = ranges;
    if (all == null) return null;
    final from = start ?? Duration.zero;
    return [
      for (final range in all)
        if ((end == null || range.start < end) && range.end > from)
          (
            start: range.start < from ? from : range.start,
            end: end != null && range.end > end ? end : range.end,
          ),
    ];
  }
}
