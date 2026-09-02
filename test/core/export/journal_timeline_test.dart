import 'package:flutter_test/flutter_test.dart';

import 'package:opentranscribe/core/export/export_helpers.dart';
import 'package:opentranscribe/core/export/journal_exporter.dart';
import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/models/reflection.dart';
import 'package:reflections/reflections.dart';

void main() {
  ExportEntry entryOn(String id, DateTime createdAt) => ExportEntry(
    entry: Entry(
      id: id,
      createdAt: createdAt,
      audioPath: null,
      duration: const Duration(seconds: 5),
    ),
  );

  Reflection reflectionOn(DateTime start, {ReflectionPeriod period = ReflectionPeriod.weekly}) =>
      Reflection(
        periodStart: start,
        period: period,
        generatedAt: DateTime.utc(2026, 8, 31),
        text: 'A stretch.',
      );

  test('days run newest first, each holding its own entries newest first', () {
    final timeline = journalTimeline(
      entries: [
        entryOn('old', DateTime(2026, 8, 5, 9)),
        entryOn('newest', DateTime(2026, 8, 7, 18)),
        entryOn('morning', DateTime(2026, 8, 7, 8)),
      ],
      reflections: const [],
    );

    expect(timeline.map((d) => d.day), [DateTime(2026, 8, 7), DateTime(2026, 8, 5)]);
    expect(timeline.first.entries.map((e) => e.entry.id), ['newest', 'morning']);
    expect(timeline.last.entries.map((e) => e.entry.id), ['old']);
  });

  test('a reflection sits on the newest day of its period that holds entries', () {
    final timeline = journalTimeline(
      entries: [
        entryOn('monday', DateTime(2026, 8, 3, 9)),
        entryOn('wednesday', DateTime(2026, 8, 5, 9)),
      ],
      reflections: [reflectionOn(DateTime(2026, 8, 3))],
    );

    expect(timeline.first.day, DateTime(2026, 8, 5));
    expect(timeline.first.reflections.single.periodStart, DateTime(2026, 8, 3));
    expect(timeline.last.reflections, isEmpty);
  });

  test('entries below a reflection stay under it rather than being pushed above', () {
    final timeline = journalTimeline(
      entries: [entryOn('after', DateTime(2026, 8, 10, 9))],
      reflections: [reflectionOn(DateTime(2026, 8, 3))],
    );

    expect(timeline.map((d) => d.day), [DateTime(2026, 8, 10), DateTime(2026, 8, 3)]);
    expect(timeline.first.entries.single.entry.id, 'after');
    expect(timeline.first.reflections, isEmpty);
    expect(timeline.last.reflections.single.periodStart, DateTime(2026, 8, 3));
  });

  test('one day carries its cards broad to narrow', () {
    final timeline = journalTimeline(
      entries: [entryOn('e1', DateTime(2026, 8, 5, 9))],
      reflections: [
        reflectionOn(DateTime(2026, 8, 5), period: ReflectionPeriod.daily),
        reflectionOn(DateTime(2026, 8), period: ReflectionPeriod.monthly),
        reflectionOn(DateTime(2026, 8, 3)),
      ],
    );

    expect(timeline.single.reflections.map((r) => r.period), [
      ReflectionPeriod.monthly,
      ReflectionPeriod.weekly,
      ReflectionPeriod.daily,
    ]);
  });

  test('a period covering no entry day falls back to its own start', () {
    final timeline = journalTimeline(
      entries: [entryOn('august', DateTime(2026, 8, 5, 9))],
      reflections: [reflectionOn(DateTime(2026, 7, 27))],
    );

    expect(timeline.map((d) => d.day), [DateTime(2026, 8, 5), DateTime(2026, 7, 27)]);
    expect(timeline.last.reflections.single.periodStart, DateTime(2026, 7, 27));
    expect(timeline.last.entries, isEmpty);
  });

  test('each reflection is seated once, on the newest day it covers', () {
    final timeline = journalTimeline(
      entries: [
        entryOn('tuesday', DateTime(2026, 8, 4, 9)),
        entryOn('thursday', DateTime(2026, 8, 6, 9)),
      ],
      reflections: [reflectionOn(DateTime(2026, 8, 3))],
    );

    expect(timeline.expand((d) => d.reflections).length, 1);
    expect(timeline.first.reflections, hasLength(1));
  });

  test('a week straddling two months stays in the month its label names', () {
    final timeline = journalTimeline(
      entries: [
        entryOn('august', DateTime(2026, 8, 1, 9)),
        entryOn('july', DateTime(2026, 7, 30, 9)),
      ],
      reflections: [reflectionOn(DateTime(2026, 7, 27))],
    );

    expect(timeline.map((d) => d.day), [DateTime(2026, 8), DateTime(2026, 7, 30)]);
    expect(timeline.first.reflections, isEmpty);
    expect(timeline.last.reflections.single.periodStart, DateTime(2026, 7, 27));
  });

  test('a week whose entries all fall in the next month still seats in its own', () {
    final timeline = journalTimeline(
      entries: [entryOn('august', DateTime(2026, 8, 1, 9))],
      reflections: [reflectionOn(DateTime(2026, 7, 27))],
    );

    expect(timeline.map((d) => d.day), [DateTime(2026, 8), DateTime(2026, 7, 27)]);
    expect(timeline.last.reflections.single.periodStart, DateTime(2026, 7, 27));
  });

  test('a period still open on the export day is kept, never filtered by a clock', () {
    final today = DateTime.now();
    final timeline = journalTimeline(
      entries: [entryOn('today', today)],
      reflections: [
        reflectionOn(DateTime(today.year, today.month, today.day), period: ReflectionPeriod.daily),
      ],
    );

    expect(timeline.single.reflections, hasLength(1));
  });

  test('two rows stored under one period both survive the export', () {
    final timeline = journalTimeline(
      entries: [entryOn('e1', DateTime(2026, 8, 5, 9))],
      reflections: [
        reflectionOn(DateTime(2026, 8, 3)),
        Reflection(
          periodStart: DateTime(2026, 8, 3),
          generatedAt: DateTime.utc(2026, 9),
          text: 'Regenerated.',
        ),
      ],
    );

    expect(timeline.single.reflections, hasLength(2));
  });

  test('an empty journal has no timeline at all', () {
    expect(journalTimeline(entries: const [], reflections: const []), isEmpty);
  });
}
