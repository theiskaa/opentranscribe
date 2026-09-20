import 'dart:io';

import 'package:transcriber/transcriber.dart';

/// A voice probe that hears [take] over the whole recording but cannot tell
/// for any slice asked on its own: a quiet voice a loud take drowns, standing
/// out no clearer than the room in its own span. Every question lands in
/// [calls].
class FakeDrownedActivity implements AudioActivity {
  FakeDrownedActivity(this.take);

  final List<VoicedRange> take;
  final List<({Duration? start, Duration? end})> calls = [];

  @override
  Future<List<VoicedRange>?> voiced(File audio, {Duration? start, Duration? end}) async {
    calls.add((start: start, end: end));
    return start == null && end == null ? take : null;
  }
}
