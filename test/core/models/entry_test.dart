import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/models/entry.dart';
import 'package:transcriber/transcriber.dart';

void main() {
  final transcript = Transcript(
    fullText: 'hello world',
    segments: const [
      TranscriptSegment(text: 'hello world', start: Duration.zero, end: Duration(seconds: 1)),
    ],
    localeId: 'en-US',
    engineId: 'fake',
    createdAt: DateTime.utc(2026, 3, 4),
  );

  Entry baseEntry() => Entry(
    id: 'abc',
    createdAt: DateTime.utc(2026, 3, 4, 9),
    audioPath: '/audio/abc.m4a',
    duration: const Duration(seconds: 12),
  );

  test('round-trips through JSON without a transcript', () {
    final entry = baseEntry();

    expect(entry.isTranscribed, isFalse);
    expect(entry.toJson().containsKey('transcript'), isFalse);
    expect(Entry.fromJson(entry.toJson()), entry);
  });

  test('normalizes a local createdAt to UTC so round-trip equality holds', () {
    final entry = Entry(
      id: 'l',
      createdAt: DateTime(2026, 3, 4, 9), // local, not UTC
      audioPath: 'l.m4a',
      duration: Duration.zero,
    );

    expect(entry.createdAt.isUtc, isTrue);
    expect(Entry.fromJson(entry.toJson()), entry);
  });

  test('round-trips through JSON with a transcript', () {
    final entry = baseEntry().withTranscript(transcript);

    expect(entry.isTranscribed, isTrue);
    expect(Entry.fromJson(entry.toJson()), entry);
  });

  test('an entry with an empty transcript is transcribed and round-trips', () {
    // Silence transcribes to an empty (not null) transcript; that is transcribed.
    final empty = Transcript(
      fullText: '',
      segments: const [],
      localeId: 'en-US',
      engineId: 'fake',
      createdAt: DateTime.utc(2026, 3, 4),
    );
    final entry = baseEntry().withTranscript(empty);

    expect(entry.isTranscribed, isTrue);
    expect(Entry.fromJson(entry.toJson()), entry);
  });

  test('withTranscript keeps identity fields and sets the transcript', () {
    final original = baseEntry();
    final updated = original.withTranscript(transcript);

    expect(updated.id, original.id);
    expect(updated.createdAt, original.createdAt);
    expect(updated.audioPath, original.audioPath);
    expect(updated.duration, original.duration);
    expect(updated.transcript, transcript);
  });

  test('title round-trips through JSON and is omitted when null', () {
    final untitled = baseEntry();
    expect(untitled.toJson().containsKey('title'), isFalse);

    final titled = untitled.withTitle('Morning pages');
    expect(titled.title, 'Morning pages');
    expect(Entry.fromJson(titled.toJson()), titled);
  });

  test('a record written before titles existed loads as untitled', () {
    final json = baseEntry().toJson()..remove('title');
    expect(Entry.fromJson(json).title, isNull);
  });

  test('withTranscript preserves the title; withTitle(null) clears it', () {
    final titled = baseEntry().withTitle('Standup thoughts');

    expect(titled.withTranscript(transcript).title, 'Standup thoughts');
    expect(titled.withTitle(null).title, isNull);
  });

  test('equality and hashCode include the title', () {
    final a = baseEntry().withTitle('x');
    final b = baseEntry().withTitle('x');
    final c = baseEntry().withTitle('y');

    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a == c, isFalse);
  });

  Entry recordedIn(String tag) => Entry(
    id: 'abc',
    createdAt: DateTime.utc(2026, 3, 4, 9),
    audioPath: '/audio/abc.m4a',
    duration: const Duration(seconds: 12),
    recordedLocaleId: tag,
  );

  test('recordedLocaleId round-trips through JSON and is omitted when null', () {
    expect(baseEntry().toJson().containsKey('recordedLocaleId'), isFalse);

    final recorded = recordedIn('fr-FR');
    expect(Entry.fromJson(recorded.toJson()), recorded);
    expect(Entry.fromJson(recorded.toJson()).recordedLocaleId, 'fr-FR');
  });

  test('a record written before per-entry language loads as unknown', () {
    final json = recordedIn('fr-FR').toJson()..remove('recordedLocaleId');
    expect(Entry.fromJson(json).recordedLocaleId, isNull);
    expect(Entry.fromJson(json).effectiveLocaleId, isNull);
  });

  test('withTranscript and withTitle preserve the recorded locale', () {
    final recorded = recordedIn('fr-FR');

    expect(recorded.withTranscript(transcript).recordedLocaleId, 'fr-FR');
    expect(recorded.withTitle('t').recordedLocaleId, 'fr-FR');
  });

  test('effectiveLocaleId prefers the transcript, falls back to the recording', () {
    // Transcribed: the transcript's language wins (it is what the text IS),
    // even over a differing recording-time locale.
    expect(recordedIn('fr-FR').withTranscript(transcript).effectiveLocaleId, 'en-US');
    // Untranscribed: the recording-time language is the honest answer.
    expect(recordedIn('fr-FR').effectiveLocaleId, 'fr-FR');
    // Neither: unknown, never guessed.
    expect(baseEntry().effectiveLocaleId, isNull);
  });

  test('equality and hashCode include the recorded locale', () {
    expect(recordedIn('fr-FR'), recordedIn('fr-FR'));
    expect(recordedIn('fr-FR') == recordedIn('de-DE'), isFalse);
  });

  test('peaks round-trip through JSON and are preserved by copies', () {
    expect(baseEntry().toJson().containsKey('peaks'), isFalse);

    final shaped = baseEntry().withPeaks(const [0, 128, 255]);
    expect(Entry.fromJson(shaped.toJson()), shaped);
    expect(Entry.fromJson(shaped.toJson()).peaks, [0, 128, 255]);

    expect(shaped.withTranscript(transcript).peaks, [0, 128, 255]);
    expect(shaped.withTitle('t').peaks, [0, 128, 255]);
    expect(shaped == baseEntry().withPeaks(const [0, 128, 255]), isTrue);
    expect(shaped == baseEntry().withPeaks(const [0, 128, 254]), isFalse);
  });

  test('a record written before peaks loads without them', () {
    final json = baseEntry().withPeaks(const [1]).toJson()..remove('peaks');
    expect(Entry.fromJson(json).peaks, isNull);
  });

  test('language spans round-trip through JSON and are preserved by copies', () {
    expect(baseEntry().toJson().containsKey('languageSpans'), isFalse);

    final mixed = Entry(
      id: 'abc',
      createdAt: DateTime.utc(2026, 3, 4, 9),
      audioPath: '/audio/abc.m4a',
      duration: const Duration(seconds: 12),
      languageSpans: const [
        LanguageSpan(startMs: 0, localeId: 'en-US'),
        LanguageSpan(startMs: 4000, localeId: 'fr-FR'),
      ],
    );
    expect(Entry.fromJson(mixed.toJson()), mixed);
    expect(mixed.withTranscript(transcript).languageSpans, mixed.languageSpans);
    expect(mixed.withTitle('t').languageSpans, mixed.languageSpans);
    expect(mixed.withPeaks(const [1]).languageSpans, mixed.languageSpans);
    expect(mixed == mixed.withTitle(null), isTrue);
  });

  test('out-of-order language spans are sorted ascending on read', () {
    // _segmentedBatch trusts ascending order; a span persisted out of order must
    // not survive the round-trip and yield a silently empty slice later.
    final json = {
      'id': 'abc',
      'createdAt': DateTime.utc(2026, 3, 4, 9).toIso8601String(),
      'audioPath': '/audio/abc.m4a',
      'durationMs': 12000,
      'languageSpans': [
        {'startMs': 4000, 'localeId': 'fr-FR'},
        {'startMs': 0, 'localeId': 'en-US'},
      ],
    };
    final entry = Entry.fromJson(json);
    expect(entry.languageSpans!.map((s) => s.startMs), [0, 4000]);
    expect(entry.languageSpans!.first.localeId, 'en-US');
  });

  test('a transcript-only entry omits audioPath and round-trips as null', () {
    expect(baseEntry().hasAudio, isTrue);

    final bare = baseEntry().withTranscript(transcript).withoutAudio();
    expect(bare.hasAudio, isFalse);
    expect(bare.toJson().containsKey('audioPath'), isFalse);
    expect(Entry.fromJson(bare.toJson()), bare);
  });

  test('withoutAudio drops only the audio reference', () {
    final full = Entry(
      id: 'abc',
      createdAt: DateTime.utc(2026, 3, 4, 9),
      audioPath: '/audio/abc.m4a',
      duration: const Duration(seconds: 12),
      transcript: transcript,
      title: 'named',
      recordedLocaleId: 'de-DE',
      peaks: const [1, 2],
      languageSpans: const [LanguageSpan(startMs: 0, localeId: 'de-DE')],
    );
    final bare = full.withoutAudio();

    expect(bare.audioPath, isNull);
    expect(bare.id, full.id);
    expect(bare.createdAt, full.createdAt);
    expect(bare.duration, full.duration);
    expect(bare.transcript, full.transcript);
    expect(bare.title, full.title);
    expect(bare.recordedLocaleId, full.recordedLocaleId);
    expect(bare.peaks, full.peaks);
    expect(bare.languageSpans, full.languageSpans);

    // Copiers keep the null: no update path resurrects a discarded reference.
    expect(bare.withTitle('t').audioPath, isNull);
    expect(bare.withPeaks(const [3]).audioPath, isNull);
    expect(bare.withTranscript(transcript).audioPath, isNull);
  });

  final editStamp = DateTime.utc(2026, 3, 5, 10);

  Revision hand(String text, {DateTime? at}) => Revision(text: text, at: at ?? editStamp);

  Revision engineRev(String text) =>
      Revision(text: text, at: DateTime.utc(2026, 3, 4), engineId: 'fake', localeId: 'en-US');

  test('revisions round-trip through JSON and are omitted when absent', () {
    expect(baseEntry().toJson().containsKey('revisions'), isFalse);

    final revised = baseEntry().withTranscript(transcript).withRevisions([
      engineRev('hello world'),
      hand('helio world'),
    ]);
    expect(Entry.fromJson(revised.toJson()), revised);
    expect(Entry.fromJson(revised.toJson()).head?.text, 'helio world');
    expect(Entry.fromJson(revised.toJson()).head?.isHand, isTrue);
  });

  test('a record written before revisions existed loads as pristine', () {
    final json = baseEntry().withRevisions([hand('x')]).toJson()..remove('revisions');
    expect(Entry.fromJson(json).revisions, isNull);
    expect(Entry.fromJson(json).head, isNull);
  });

  test('an empty history normalizes to pristine, one spelling everywhere', () {
    final emptied = baseEntry().withRevisions(const []);
    expect(emptied.revisions, isNull);
    expect(emptied, baseEntry());
    expect(emptied.toJson().containsKey('revisions'), isFalse);
  });

  test('a legacy overlay record folds into an engine base and a hand head', () {
    final json = baseEntry().withTranscript(transcript).toJson()
      ..['editedText'] = 'helio world'
      ..['editedAt'] = editStamp.toIso8601String();
    final folded = Entry.fromJson(json);

    expect(folded.revisions, hasLength(2));
    expect(folded.revisions!.first.text, 'hello world');
    expect(folded.revisions!.first.engineId, 'fake');
    expect(folded.head?.text, 'helio world');
    expect(folded.head?.isHand, isTrue);
    expect(folded.head?.at, editStamp);
  });

  test('half a legacy overlay pair reads as pristine', () {
    final textOnly = baseEntry().toJson()..['editedText'] = 'x';
    expect(Entry.fromJson(textOnly).revisions, isNull);

    final stampOnly = baseEntry().toJson()..['editedAt'] = editStamp.toIso8601String();
    expect(Entry.fromJson(stampOnly).revisions, isNull);
  });

  test('a legacy edit over a silent transcript folds without a base', () {
    final silent = Transcript(
      fullText: '   ',
      segments: const [
        TranscriptSegment(text: '   ', start: Duration.zero, end: Duration(seconds: 1)),
      ],
      localeId: 'en-US',
      engineId: 'fake',
      createdAt: DateTime.utc(2026, 3, 4),
    );
    final json = baseEntry().withTranscript(silent).toJson()
      ..['editedText'] = 'typed over silence'
      ..['editedAt'] = editStamp.toIso8601String();
    final folded = Entry.fromJson(json);

    expect(folded.revisions, hasLength(1));
    expect(folded.head?.text, 'typed over silence');
    expect(folded.head?.isHand, isTrue);
  });

  test('normalizes a local revision stamp to UTC so round-trip equality holds', () {
    final revised = baseEntry().withRevisions([hand('x', at: DateTime(2026, 3, 5, 10))]);
    expect(revised.head!.at.isUtc, isTrue);
    expect(Entry.fromJson(revised.toJson()), revised);
  });

  test('withRevisions swaps the history and keeps everything else', () {
    final full = baseEntry().withTranscript(transcript).withTitle('named').withPeaks(const [1, 2]);
    final revised = full.withRevisions([hand('fixed')]);

    expect(revised.head?.text, 'fixed');
    expect(revised.transcript, full.transcript);
    expect(revised.title, full.title);
    expect(revised.peaks, full.peaks);
    expect(revised.audioPath, full.audioPath);
  });

  test('the other copiers preserve the history', () {
    final revised = baseEntry().withRevisions([hand('fixed')]);

    for (final copy in [
      revised.withTranscript(transcript),
      revised.withTitle('t'),
      revised.withPeaks(const [1]),
      revised.withoutAudio(),
      revised.withAudioPath('b.m4a'),
      revised.withRecording('c.m4a', Duration.zero),
      revised.withLanguageSpans(null),
    ]) {
      expect(copy.head?.text, 'fixed');
      expect(copy.head?.at, editStamp);
    }
  });

  test('withRecording repoints the recording, keeps the rest and drops the peaks', () {
    const spans = [
      LanguageSpan(startMs: 0, localeId: 'en-US'),
      LanguageSpan(startMs: 5000, localeId: 'fr-FR'),
    ];
    final full = Entry(
      id: 'abc',
      createdAt: DateTime.utc(2026, 3, 4, 9),
      audioPath: 'otr-old.m4a',
      duration: const Duration(seconds: 12),
      transcript: transcript,
      title: 't',
      recordedLocaleId: 'en-US',
      peaks: const [1, 2, 3],
      languageSpans: spans,
      revisions: [Revision.ofTranscript(transcript)],
    );

    final entry = full.withRecording('otr-new.m4a', const Duration(seconds: 30));

    expect(entry.audioPath, 'otr-new.m4a');
    expect(entry.duration, const Duration(seconds: 30));
    expect(entry.peaks, isNull);
    expect(entry.transcript, transcript);
    expect(entry.title, 't');
    expect(entry.recordedLocaleId, 'en-US');
    expect(entry.languageSpans, spans);
    expect(entry.revisions, full.revisions);
  });

  test('withLanguageSpans swaps the mix and null flattens it', () {
    const spans = [
      LanguageSpan(startMs: 0, localeId: 'en-US'),
      LanguageSpan(startMs: 5000, localeId: 'fr-FR'),
    ];
    final mixed = baseEntry().withPeaks(const [9]).withLanguageSpans(spans);

    expect(mixed.languageSpans, spans);
    expect(mixed.peaks, const [9]);
    expect(Entry.fromJson(mixed.withLanguageSpans(null).toJson()).languageSpans, isNull);
  });

  test('readableText prefers the head and falls back to the transcript', () {
    expect(baseEntry().readableText, isNull);
    expect(baseEntry().withTranscript(transcript).readableText, 'hello world');
    expect(
      baseEntry().withTranscript(transcript).withRevisions([hand('fixed')]).readableText,
      'fixed',
    );
  });

  test('a hand head over an empty transcript reads as the head', () {
    final silent = Transcript(
      fullText: '',
      segments: const [],
      localeId: 'en-US',
      engineId: 'fake',
      createdAt: DateTime.utc(2026, 3, 4),
    );
    final typed = baseEntry().withTranscript(silent).withRevisions([hand('typed in')]);
    expect(typed.readableText, 'typed in');
  });

  test('readsAsTranscript holds for a pristine entry and a matching engine head', () {
    expect(baseEntry().readsAsTranscript, isTrue);
    expect(baseEntry().withTranscript(transcript).readsAsTranscript, isTrue);
    expect(
      baseEntry().withTranscript(transcript).withRevisions([
        engineRev('hello world'),
      ]).readsAsTranscript,
      isTrue,
    );
  });

  test('readsAsTranscript reads whitespace-blind under an engine head', () {
    final variant = baseEntry().withTranscript(transcript).withRevisions([
      Revision(
        text: ' hello  world',
        at: DateTime.utc(2026, 3, 4),
        engineId: 'fake',
        localeId: 'en-US',
      ),
    ]);
    expect(variant.readsAsTranscript, isTrue);
  });

  test('readsAsTranscript falls for a hand head and a stale engine head', () {
    final entry = baseEntry().withTranscript(transcript);
    expect(entry.withRevisions([hand('fixed')]).readsAsTranscript, isFalse);
    expect(entry.withRevisions([engineRev('older engine words')]).readsAsTranscript, isFalse);
  });

  test('equality and hashCode include the history', () {
    final a = baseEntry().withRevisions([hand('x')]);
    final b = baseEntry().withRevisions([hand('x')]);
    final c = baseEntry().withRevisions([hand('y')]);

    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a == c, isFalse);
    expect(a == baseEntry(), isFalse);
    expect(a == baseEntry().withRevisions([hand('x', at: DateTime.utc(2026, 3, 6))]), isFalse);
  });
}
