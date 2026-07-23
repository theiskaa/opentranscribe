import 'package:flutter/foundation.dart';

/// A single timed span of recognized text.
@immutable
class TranscriptSegment {
  const TranscriptSegment({
    required this.text,
    required this.start,
    required this.end,
    this.confidence,
  });

  final String text;
  final Duration start;
  final Duration end;
  final double? confidence;

  Map<String, dynamic> toJson() => {
    'text': text,
    'startMs': start.inMilliseconds,
    'endMs': end.inMilliseconds,
    if (confidence != null) 'confidence': confidence,
  };

  factory TranscriptSegment.fromJson(Map<String, dynamic> json) => TranscriptSegment(
    text: json['text'] as String,
    start: Duration(milliseconds: json['startMs'] as int),
    end: Duration(milliseconds: json['endMs'] as int),
    confidence: (json['confidence'] as num?)?.toDouble(),
  );

  @override
  bool operator ==(Object other) =>
      other is TranscriptSegment &&
      other.text == text &&
      other.start == start &&
      other.end == end &&
      other.confidence == confidence;

  @override
  int get hashCode => Object.hash(text, start, end, confidence);
}

/// The output of a transcription: full text plus timed segments, tagged with the
/// engine and locale that produced it so a re-transcription is traceable.
@immutable
class Transcript {
  const Transcript({
    required this.fullText,
    required this.segments,
    required this.localeId,
    required this.engineId,
    required this.createdAt,
  });

  final String fullText;
  final List<TranscriptSegment> segments;
  final String localeId;
  final String engineId;
  final DateTime createdAt;

  /// Silence transcribes to an empty transcript, which is a valid result.
  bool get isEmpty => fullText.isEmpty;

  Map<String, dynamic> toJson() => {
    'fullText': fullText,
    'segments': segments.map((s) => s.toJson()).toList(),
    'localeId': localeId,
    'engineId': engineId,
    // Store UTC so timestamps survive travel and DST unchanged.
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  factory Transcript.fromJson(Map<String, dynamic> json) => Transcript(
    fullText: json['fullText'] as String,
    segments: (json['segments'] as List<dynamic>)
        .map((e) => TranscriptSegment.fromJson(e as Map<String, dynamic>))
        .toList(),
    localeId: json['localeId'] as String,
    engineId: json['engineId'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  @override
  bool operator ==(Object other) =>
      other is Transcript &&
      other.fullText == fullText &&
      listEquals(other.segments, segments) &&
      other.localeId == localeId &&
      other.engineId == engineId &&
      other.createdAt == createdAt;

  @override
  int get hashCode =>
      Object.hash(fullText, Object.hashAll(segments), localeId, engineId, createdAt);
}
