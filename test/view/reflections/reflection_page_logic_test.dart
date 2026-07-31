import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/models/reflection.dart';
import 'package:opentranscribe/core/models/reflection_timeline.dart';
import 'package:opentranscribe/core/reflect/reflection_options.dart';
import 'package:opentranscribe/view/layouts/reflections/components/reflection_page_logic.dart';
import 'package:opentranscribe/view/widgets/ink_reveal.dart';

void main() {
  final weekStart = DateTime(2026, 7, 20);

  ReflectionWeek reflected({DateTime? generatedAt}) => ReflectionWeek(
    weekStart: weekStart,
    status: ReflectionWeekStatus.reflected,
    reflection: Reflection(
      weekStart: weekStart,
      generatedAt: generatedAt ?? DateTime.utc(2026, 7, 27),
      text: 'a week',
    ),
  );

  test('the first view of a reflected week writes on', () {
    expect(inkPhaseFor(week: reflected(), regenerating: false, revealed: const {}), InkPhase.write);
  });

  test('a week already revealed this visit arrives settled', () {
    final week = reflected();
    final revealed = {revealKeyFor(week)};
    expect(inkPhaseFor(week: week, regenerating: false, revealed: revealed), InkPhase.settled);
  });

  test('a regenerating week is pending even when previously revealed', () {
    final week = reflected();
    final revealed = {revealKeyFor(week)};
    expect(inkPhaseFor(week: week, regenerating: true, revealed: revealed), InkPhase.pending);
  });

  test('a regenerate changes the ledger key, so the new words re-arrive', () {
    // Marked at reveal START: an interrupted reveal does not replay on return,
    // but a new generatedAt is a different key and earns its arrival again.
    final first = reflected();
    final revealed = {revealKeyFor(first)};
    final rewritten = reflected(generatedAt: DateTime.utc(2026, 7, 28));
    expect(revealKeyFor(rewritten), isNot(revealKeyFor(first)));
    expect(inkPhaseFor(week: rewritten, regenerating: false, revealed: revealed), InkPhase.write);
  });

  test('placeholder height follows the length knob', () {
    expect(placeholderLinesFor(ReflectionLength.oneLine), 3);
    expect(placeholderLinesFor(ReflectionLength.sentences), 5);
    expect(placeholderLinesFor(ReflectionLength.paragraph), 8);
  });

  test('a regenerate cloud is shaped like the text it replaces', () {
    // 400 chars at a 360pt measure lays out to a handful of lines: the cloud
    // must scale with the old text, not sit at the knob's fixed height.
    final short = ReflectionWeek(
      weekStart: weekStart,
      status: ReflectionWeekStatus.reflected,
      reflection: Reflection(
        weekStart: weekStart,
        generatedAt: DateTime.utc(2026, 7, 27),
        text: 'One brief line.',
      ),
    );
    final long = ReflectionWeek(
      weekStart: weekStart,
      status: ReflectionWeekStatus.reflected,
      reflection: Reflection(
        weekStart: weekStart,
        generatedAt: DateTime.utc(2026, 7, 27),
        text: 'x' * 400,
      ),
    );
    final shortLines = pendingLinesFor(week: short, width: 360, length: ReflectionLength.paragraph);
    final longLines = pendingLinesFor(week: long, width: 360, length: ReflectionLength.paragraph);
    expect(shortLines, 1);
    expect(longLines, greaterThan(shortLines));
  });

  test('a week with no text falls back to the length knob', () {
    final silent = ReflectionWeek(
      weekStart: weekStart,
      status: ReflectionWeekStatus.silent,
      reflection: Reflection(weekStart: weekStart, generatedAt: DateTime.utc(2026, 7, 27)),
    );
    expect(
      pendingLinesFor(week: silent, width: 360, length: ReflectionLength.sentences),
      placeholderLinesFor(ReflectionLength.sentences),
    );
  });

  group('eagerPageTarget', () {
    test('a short drag commits once it clears the threshold, either way', () {
      expect(eagerPageTarget(page: 3.25, from: 3, flick: 0), 4);
      expect(eagerPageTarget(page: 2.75, from: 3, flick: 0), 2);
    });

    test('exactly at the threshold the page springs home (the comparison is strict)', () {
      // A binary-exact threshold: 3.2 - 3 lands a hair over 0.2 in doubles
      // and would test float noise, not the rule.
      expect(eagerPageTarget(page: 3.25, from: 3, flick: 0, threshold: 0.25), 3);
      expect(eagerPageTarget(page: 2.75, from: 3, flick: 0, threshold: 0.25), 3);
    });

    test('under the threshold the page springs home', () {
      // The framework would demand 50%; the whole point is committing early,
      // but a graze must still return.
      expect(eagerPageTarget(page: 3.1, from: 3, flick: 0), 3);
      expect(eagerPageTarget(page: 2.9, from: 3, flick: 0), 3);
    });

    test('any flick commits in its direction regardless of distance', () {
      expect(eagerPageTarget(page: 3.05, from: 3, flick: 1), 4);
      expect(eagerPageTarget(page: 2.95, from: 3, flick: -1), 2);
    });

    test('a stale anchor re-anchors to the nearest page', () {
      // A second swipe can start before the first settles: the anchor is then
      // a full page behind and must not drag the target back.
      expect(eagerPageTarget(page: 4.3, from: 3, flick: 0), 5);
      expect(eagerPageTarget(page: 4.1, from: 3, flick: 0), 4);
    });
  });
}
