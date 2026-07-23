import 'package:flutter/foundation.dart';

import 'package:opentranscribe/core/transcribe/transcript.dart';

/// A live transcription update from a streaming engine. Text grows as you speak;
/// [isFinal] marks the last event, whose text is the settled transcription.
@immutable
final class TranscriptEvent {
  const TranscriptEvent({required this.text, required this.isFinal, this.segments = const []});

  final String text;
  final bool isFinal;
  final List<TranscriptSegment> segments;

  @override
  bool operator ==(Object other) =>
      other is TranscriptEvent &&
      other.text == text &&
      other.isFinal == isFinal &&
      listEquals(other.segments, segments);

  @override
  int get hashCode => Object.hash(text, isFinal, Object.hashAll(segments));
}
