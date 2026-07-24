import 'package:flutter/foundation.dart';

import 'package:opentranscribe/core/transcribe/transcript.dart';

/// One journal entry: a kept recording and, once transcribed, its transcript.
/// The audio is the source of truth and is kept so the entry can be re-transcribed
/// by a better engine later. The transcript is null until transcription completes.
@immutable
final class Entry {
  /// [createdAt] is normalized to UTC here, so round-trip equality through JSON
  /// (which stores UTC) holds no matter what clock a caller passed in.
  Entry({
    required this.id,
    required DateTime createdAt,
    required this.audioPath,
    required this.duration,
    this.transcript,
    this.title,
  }) : createdAt = createdAt.toUtc();

  final String id;
  final DateTime createdAt;
  final String audioPath;
  final Duration duration;
  final Transcript? transcript;

  /// User-set display title. Null means untitled; the UI renders a localized
  /// date-time default in that case, which is presentation, not data.
  final String? title;

  bool get isTranscribed => transcript != null;

  /// Returns a copy carrying a new transcript. Used after (re-)transcription.
  Entry withTranscript(Transcript transcript) => Entry(
    id: id,
    createdAt: createdAt,
    audioPath: audioPath,
    duration: duration,
    transcript: transcript,
    title: title,
  );

  /// Returns a copy with the user-set title; null clears back to untitled.
  Entry withTitle(String? title) => Entry(
    id: id,
    createdAt: createdAt,
    audioPath: audioPath,
    duration: duration,
    transcript: transcript,
    title: title,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    // Store UTC so timestamps survive travel and DST unchanged.
    'createdAt': createdAt.toUtc().toIso8601String(),
    'audioPath': audioPath,
    'durationMs': duration.inMilliseconds,
    if (transcript != null) 'transcript': transcript!.toJson(),
    if (title != null) 'title': title,
  };

  factory Entry.fromJson(Map<String, dynamic> json) => Entry(
    id: json['id'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    audioPath: json['audioPath'] as String,
    duration: Duration(milliseconds: json['durationMs'] as int),
    transcript: json['transcript'] == null
        ? null
        : Transcript.fromJson(json['transcript'] as Map<String, dynamic>),
    // Absent in records written before titles existed; null is untitled.
    title: json['title'] as String?,
  );

  @override
  bool operator ==(Object other) =>
      other is Entry &&
      other.id == id &&
      other.createdAt == createdAt &&
      other.audioPath == audioPath &&
      other.duration == duration &&
      other.transcript == transcript &&
      other.title == title;

  @override
  int get hashCode => Object.hash(id, createdAt, audioPath, duration, transcript, title);
}
