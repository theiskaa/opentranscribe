import 'package:flutter/foundation.dart';

import 'package:opentranscribe/core/transcribe/transcript.dart';

/// One language stretch of a recording spoken in several: from [startMs] of
/// audio time until the next span begins (the last runs to the end). Kept on
/// the entry so a re-transcription can rebuild the mix instead of flattening
/// it into one language.
@immutable
final class LanguageSpan {
  const LanguageSpan({required this.startMs, required this.localeId});

  final int startMs;
  final String localeId;

  Map<String, dynamic> toJson() => {'startMs': startMs, 'localeId': localeId};

  factory LanguageSpan.fromJson(Map<String, dynamic> json) =>
      LanguageSpan(startMs: (json['startMs'] as num).toInt(), localeId: json['localeId'] as String);

  @override
  bool operator ==(Object other) =>
      other is LanguageSpan && other.startMs == startMs && other.localeId == localeId;

  @override
  int get hashCode => Object.hash(startMs, localeId);
}

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
    this.recordedLocaleId,
    this.peaks,
    this.languageSpans,
  }) : createdAt = createdAt.toUtc();

  final String id;
  final DateTime createdAt;
  final String audioPath;
  final Duration duration;
  final Transcript? transcript;

  /// User-set display title. Null means untitled; the UI renders a localized
  /// date-time default in that case, which is presentation, not data.
  final String? title;

  /// The transcription language in effect when this was RECORDED, so an entry
  /// saved untranscribed (an interruption, a failed first pass) still knows
  /// what language it is in when transcribed later. Null on entries from
  /// before this field and on recovered orphans, whose language is honestly
  /// unknown.
  final String? recordedLocaleId;

  /// The recording's amplitude envelope, quantized to 0..255, computed ONCE
  /// (at save or on the first open) so viewing an entry never re-decodes the
  /// whole audio file. Null on entries from before peaks were persisted; the
  /// player backfills them lazily.
  final List<int>? peaks;

  /// The language spans of a take spoken in SEVERAL languages (mid-recording
  /// switches), ascending by start. Null for the common single-language take.
  final List<LanguageSpan>? languageSpans;

  bool get isTranscribed => transcript != null;

  /// The language this entry is known to be in: its transcript's, else the
  /// one it was recorded under. Null means unknown; actions then fall back to
  /// the app default. The one rule every flow resolves through, so a default
  /// change can never silently re-language an entry.
  String? get effectiveLocaleId => transcript?.localeId ?? recordedLocaleId;

  /// Returns a copy carrying a new transcript. Used after (re-)transcription.
  Entry withTranscript(Transcript transcript) => Entry(
    id: id,
    createdAt: createdAt,
    audioPath: audioPath,
    duration: duration,
    transcript: transcript,
    title: title,
    recordedLocaleId: recordedLocaleId,
    peaks: peaks,
    languageSpans: languageSpans,
  );

  /// Returns a copy with the user-set title; null clears back to untitled.
  Entry withTitle(String? title) => Entry(
    id: id,
    createdAt: createdAt,
    audioPath: audioPath,
    duration: duration,
    transcript: transcript,
    title: title,
    recordedLocaleId: recordedLocaleId,
    peaks: peaks,
    languageSpans: languageSpans,
  );

  /// Returns a copy carrying the computed amplitude envelope.
  Entry withPeaks(List<int> peaks) => Entry(
    id: id,
    createdAt: createdAt,
    audioPath: audioPath,
    duration: duration,
    transcript: transcript,
    title: title,
    recordedLocaleId: recordedLocaleId,
    peaks: peaks,
    languageSpans: languageSpans,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    // Store UTC so timestamps survive travel and DST unchanged.
    'createdAt': createdAt.toUtc().toIso8601String(),
    'audioPath': audioPath,
    'durationMs': duration.inMilliseconds,
    if (transcript != null) 'transcript': transcript!.toJson(),
    if (title != null) 'title': title,
    if (recordedLocaleId != null) 'recordedLocaleId': recordedLocaleId,
    if (peaks != null) 'peaks': peaks,
    if (languageSpans != null) 'languageSpans': [for (final s in languageSpans!) s.toJson()],
  };

  factory Entry.fromJson(Map<String, dynamic> json) {
    // Sorted ascending by start on read: _segmentedBatch's slice math trusts the
    // order, and a persisted span out of order would yield a silently empty slice.
    final spans = (json['languageSpans'] as List?)
        ?.map((s) => LanguageSpan.fromJson((s as Map).cast<String, dynamic>()))
        .toList();
    spans?.sort((a, b) => a.startMs.compareTo(b.startMs));
    return Entry(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      audioPath: json['audioPath'] as String,
      duration: Duration(milliseconds: (json['durationMs'] as num).toInt()),
      transcript: json['transcript'] == null
          ? null
          : Transcript.fromJson(json['transcript'] as Map<String, dynamic>),
      // Absent in records written before titles existed; null is untitled.
      title: json['title'] as String?,
      // Absent in records written before per-entry language; null is unknown.
      recordedLocaleId: json['recordedLocaleId'] as String?,
      // Absent in records written before peaks were persisted; backfilled lazily.
      peaks: (json['peaks'] as List?)?.map((v) => (v as num).toInt()).toList(),
      languageSpans: spans,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Entry &&
      other.id == id &&
      other.createdAt == createdAt &&
      other.audioPath == audioPath &&
      other.duration == duration &&
      other.transcript == transcript &&
      other.title == title &&
      other.recordedLocaleId == recordedLocaleId &&
      listEquals(other.peaks, peaks) &&
      listEquals(other.languageSpans, languageSpans);

  @override
  int get hashCode => Object.hash(
    id,
    createdAt,
    audioPath,
    duration,
    transcript,
    title,
    recordedLocaleId,
    peaks == null ? null : Object.hashAll(peaks!),
    languageSpans == null ? null : Object.hashAll(languageSpans!),
  );
}
