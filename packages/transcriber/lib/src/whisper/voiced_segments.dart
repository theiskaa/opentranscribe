import 'package:transcriber/src/audio/audio_activity.dart';
import 'package:transcriber/src/whisper/whisper_runtime.dart';

/// How far a segment may sit from a voice and still be its words: whisper's
/// segment times drift from the audio, and a lost word costs more than a
/// stray one.
const Duration voiceMargin = Duration(seconds: 1);

final RegExp _wordy = RegExp(r'[\p{L}\p{N}]', unicode: true);

/// [heard], timed from a slice's start, without what whisper wrote into
/// silence, which it does because every slice is padded to its 30 s window:
/// a segment with no letter or digit ("...") goes, as does one starting at or
/// past [length] or more than [voiceMargin] from every range in [voiced] (the
/// same timeline), and every end is clamped to [length]. Null [voiced], a probe
/// that could not tell, keeps every segment inside the slice with words.
List<WhisperSegment> keepVoiced(
  List<WhisperSegment> heard, {
  required List<VoicedRange>? voiced,
  required Duration length,
}) => heard
    .where((segment) => segment.start < length && _wordy.hasMatch(segment.text))
    .map((segment) => _clamped(segment, length))
    .where((segment) => voiced == null || voiced.any((range) => _near(range, segment)))
    .toList();

WhisperSegment _clamped(WhisperSegment segment, Duration length) {
  final end = segment.end < segment.start
      ? segment.start
      : (segment.end < length ? segment.end : length);
  return WhisperSegment(
    text: segment.text,
    start: segment.start,
    end: end,
    confidence: segment.confidence,
  );
}

bool _near(VoicedRange range, WhisperSegment segment) =>
    range.start - voiceMargin <= segment.end && range.end + voiceMargin >= segment.start;
