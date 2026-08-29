import 'package:flutter/foundation.dart';

import 'package:opentranscribe/core/utils/word_diff.dart';
import 'package:transcriber/transcriber.dart';

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

/// One state the entry's text has been through: what it said, when it began
/// saying it, and who wrote it. A null [engineId] is a hand edit; an engine
/// revision carries the engine and language that produced it. Revisions are
/// history, never rewritten: a restore pushes a copy rather than truncating.
@immutable
final class Revision {
  /// [at] is normalized to UTC here, so round-trip equality through JSON
  /// (which stores UTC) holds no matter what clock a caller passed in.
  Revision({required this.text, required DateTime at, this.engineId, this.localeId})
    : at = at.toUtc();

  /// The engine revision a [transcript] IS: same words, same stamp, same
  /// producer. The one constructor for engine revisions, so their text can
  /// never drift from the transcript they landed with.
  Revision.ofTranscript(Transcript transcript)
    : this(
        text: transcript.fullText,
        at: transcript.createdAt,
        engineId: transcript.engineId,
        localeId: transcript.localeId,
      );

  final String text;
  final DateTime at;
  final String? engineId;
  final String? localeId;

  /// Whether this text was typed rather than heard.
  bool get isHand => engineId == null;

  Map<String, dynamic> toJson() => {
    'text': text,
    'at': at.toUtc().toIso8601String(),
    if (engineId != null) 'engineId': engineId,
    if (localeId != null) 'localeId': localeId,
  };

  factory Revision.fromJson(Map<String, dynamic> json) => Revision(
    text: json['text'] as String,
    at: DateTime.parse(json['at'] as String),
    engineId: json['engineId'] as String?,
    localeId: json['localeId'] as String?,
  );

  @override
  bool operator ==(Object other) =>
      other is Revision &&
      other.text == text &&
      other.at == at &&
      other.engineId == engineId &&
      other.localeId == localeId;

  @override
  int get hashCode => Object.hash(text, at, engineId, localeId);
}

/// One journal entry: a kept recording and, once transcribed, its transcript.
/// While present, the audio is the source of truth and is kept so the entry can
/// be re-transcribed by a better engine later. A null [audioPath] means the
/// audio was discarded - the keep-audio preference deleting it after a
/// successful transcription, or the Cache screen's explicit clear: the entry is
/// transcript-only, cannot be played back, and can never be re-transcribed. The
/// transcript is null until transcription completes.
@immutable
final class Entry {
  /// [createdAt] is normalized to UTC here, so round-trip equality through JSON
  /// (which stores UTC) holds no matter what clock a caller passed in.
  /// [revisions] is wrapped unmodifiable so a shared reference cannot be
  /// mutated under ==/hashCode; an empty list normalizes to null, so pristine
  /// has one spelling however it was reached.
  Entry({
    required this.id,
    required DateTime createdAt,
    required this.audioPath,
    required this.duration,
    this.transcript,
    this.title,
    this.recordedLocaleId,
    this.peaks,
    List<LanguageSpan>? languageSpans,
    List<Revision>? revisions,
  }) : createdAt = createdAt.toUtc(),
       languageSpans = languageSpans == null || languageSpans.isEmpty ? null : languageSpans,
       revisions = revisions == null || revisions.isEmpty ? null : List.unmodifiable(revisions);

  final String id;
  final DateTime createdAt;

  /// Required but nullable: every creation site must decide, so a flow cannot
  /// forget the path by omission. Null means the audio was discarded.
  final String? audioPath;
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

  /// Every state the text has been through, ascending; the LAST is what the
  /// entry reads as. Null means pristine: only ever the first transcript,
  /// nothing extra stored. The stack materializes on the first change (the
  /// engine base is pushed under it, so history starts at the beginning) and
  /// only ever grows; [transcript] still carries the latest engine output
  /// with its timings.
  final List<Revision>? revisions;

  bool get isTranscribed => transcript != null;

  bool get hasAudio => audioPath != null;

  /// The language this entry is known to be in: its transcript's, else the
  /// one it was recorded under. Null means unknown; actions then fall back to
  /// the app default. The one rule every flow resolves through, so a default
  /// change can never silently re-language an entry.
  String? get effectiveLocaleId => transcript?.localeId ?? recordedLocaleId;

  /// The newest revision, what the entry currently reads as; null while
  /// pristine.
  Revision? get head => revisions?.last;

  /// The text this entry reads as: the head revision when one exists, else
  /// the engine's transcript. The one accessor every surface reads transcript
  /// text through, so a change can never be bypassed by accident.
  String? get readableText => head?.text ?? transcript?.fullText;

  /// Whether what the entry reads as IS the current transcript (whitespace
  /// aside, like the landings that skip pushing decide it), so playback
  /// marking may light segments and no edited marker shows. False under a
  /// hand head, and under a restored OLD engine head whose words the current
  /// timings no longer name.
  bool get readsAsTranscript {
    final head = this.head;
    if (head == null) return true;
    return !head.isHand && sameWords(head.text, transcript?.fullText ?? '');
  }

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
    revisions: revisions,
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
    revisions: revisions,
  );

  /// Returns a copy referencing [audioPath] instead. Import uses it when a
  /// restored recording must land under a fresh filename because the original
  /// basename already belongs to a different entry.
  Entry withAudioPath(String audioPath) => Entry(
    id: id,
    createdAt: createdAt,
    audioPath: audioPath,
    duration: duration,
    transcript: transcript,
    title: title,
    recordedLocaleId: recordedLocaleId,
    peaks: peaks,
    languageSpans: languageSpans,
    revisions: revisions,
  );

  /// Returns a copy with the audio reference dropped: the transcript-only form
  /// an entry takes after its recording is discarded under keep-audio off.
  Entry withoutAudio() => Entry(
    id: id,
    createdAt: createdAt,
    audioPath: null,
    duration: duration,
    transcript: transcript,
    title: title,
    recordedLocaleId: recordedLocaleId,
    peaks: peaks,
    languageSpans: languageSpans,
    revisions: revisions,
  );

  /// Returns a copy pointing at a new recording. Peaks are dropped: the
  /// envelope described the old file, and the backfill recomputes only when
  /// they are absent.
  Entry withRecording(String audioPath, Duration duration) => Entry(
    id: id,
    createdAt: createdAt,
    audioPath: audioPath,
    duration: duration,
    transcript: transcript,
    title: title,
    recordedLocaleId: recordedLocaleId,
    languageSpans: languageSpans,
    revisions: revisions,
  );

  /// Returns a copy carrying [spans] as the language mix; null flattens to
  /// one language, like a fresh single-language take.
  Entry withLanguageSpans(List<LanguageSpan>? spans) => Entry(
    id: id,
    createdAt: createdAt,
    audioPath: audioPath,
    duration: duration,
    transcript: transcript,
    title: title,
    recordedLocaleId: recordedLocaleId,
    peaks: peaks,
    languageSpans: spans,
    revisions: revisions,
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
    revisions: revisions,
  );

  /// Returns a copy carrying [revisions] as the text history. The service
  /// composes the pushes; this only swaps the list.
  Entry withRevisions(List<Revision> revisions) => Entry(
    id: id,
    createdAt: createdAt,
    audioPath: audioPath,
    duration: duration,
    transcript: transcript,
    title: title,
    recordedLocaleId: recordedLocaleId,
    peaks: peaks,
    languageSpans: languageSpans,
    revisions: revisions,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    // Store UTC so timestamps survive travel and DST unchanged.
    'createdAt': createdAt.toUtc().toIso8601String(),
    if (audioPath != null) 'audioPath': audioPath,
    'durationMs': duration.inMilliseconds,
    if (transcript != null) 'transcript': transcript!.toJson(),
    if (title != null) 'title': title,
    if (recordedLocaleId != null) 'recordedLocaleId': recordedLocaleId,
    if (peaks != null) 'peaks': peaks,
    if (languageSpans != null) 'languageSpans': [for (final s in languageSpans!) s.toJson()],
    if (revisions != null) 'revisions': [for (final r in revisions!) r.toJson()],
  };

  factory Entry.fromJson(Map<String, dynamic> json) {
    // Sorted ascending by start on read: _segmentedBatch's slice math trusts the
    // order, and a persisted span out of order would yield a silently empty slice.
    final spans = (json['languageSpans'] as List?)
        ?.map((s) => LanguageSpan.fromJson((s as Map).cast<String, dynamic>()))
        .toList();
    spans?.sort((a, b) => a.startMs.compareTo(b.startMs));
    final transcript = json['transcript'] == null
        ? null
        : Transcript.fromJson(json['transcript'] as Map<String, dynamic>);
    var revisions = (json['revisions'] as List?)
        ?.map((r) => Revision.fromJson((r as Map).cast<String, dynamic>()))
        .toList();
    // Records written under the short-lived overlay model (editedText and
    // editedAt beside the transcript) fold into a stack: the engine base,
    // then the hand edit. Half a pair reads as pristine, and a SILENT
    // transcript lays no base (the service's rule: no words to remember),
    // so a blank revision can never enter history through here.
    final legacyText = json['editedText'] as String?;
    final legacyAt = json['editedAt'] == null ? null : DateTime.parse(json['editedAt'] as String);
    if (revisions == null && legacyText != null && legacyAt != null) {
      revisions = [
        if (transcript != null && transcript.fullText.trim().isNotEmpty)
          Revision.ofTranscript(transcript),
        Revision(text: legacyText, at: legacyAt),
      ];
    }
    return Entry(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      // Absent on transcript-only entries whose audio was discarded.
      audioPath: json['audioPath'] as String?,
      duration: Duration(milliseconds: (json['durationMs'] as num).toInt()),
      transcript: transcript,
      // Absent in records written before titles existed; null is untitled.
      title: json['title'] as String?,
      // Absent in records written before per-entry language; null is unknown.
      recordedLocaleId: json['recordedLocaleId'] as String?,
      // Absent in records written before peaks were persisted; backfilled lazily.
      peaks: (json['peaks'] as List?)?.map((v) => (v as num).toInt()).toList(),
      languageSpans: spans,
      revisions: revisions,
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
      listEquals(other.languageSpans, languageSpans) &&
      listEquals(other.revisions, revisions);

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
    revisions == null ? null : Object.hashAll(revisions!),
  );
}
