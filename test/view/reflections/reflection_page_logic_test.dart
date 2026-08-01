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

  InkPhase phaseFor(
    ReflectionWeek week, {
    bool regenerating = false,
    bool scrubbing = false,
    Set<String> revealed = const {},
  }) =>
      inkPhaseFor(week: week, regenerating: regenerating, scrubbing: scrubbing, revealed: revealed);

  test('the first view of a reflected week writes on', () {
    expect(phaseFor(reflected()), InkPhase.write);
  });

  test('a week already revealed this visit arrives settled', () {
    final week = reflected();
    expect(phaseFor(week, revealed: {revealKeyFor(week)}), InkPhase.settled);
  });

  test('a regenerating week is pending even when previously revealed', () {
    final week = reflected();
    expect(phaseFor(week, regenerating: true, revealed: {revealKeyFor(week)}), InkPhase.pending);
  });

  test('a scrub renders an unrevealed week settled, so flying past starts no write', () {
    expect(phaseFor(reflected(), scrubbing: true), InkPhase.settled);
  });

  test('a regenerating week stays pending under a scrub', () {
    expect(phaseFor(reflected(), regenerating: true, scrubbing: true), InkPhase.pending);
  });

  test('a regenerate changes the ledger key, so the new words re-arrive', () {
    // Marked at reveal START: an interrupted reveal does not replay on return,
    // but a new generatedAt is a different key and earns its arrival again.
    final first = reflected();
    final rewritten = reflected(generatedAt: DateTime.utc(2026, 7, 28));
    expect(revealKeyFor(rewritten), isNot(revealKeyFor(first)));
    expect(phaseFor(rewritten, revealed: {revealKeyFor(first)}), InkPhase.write);
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
    final shortLines = pendingLinesFor(
      week: short,
      width: 360,
      fontSize: 17,
      length: ReflectionLength.paragraph,
    );
    final longLines = pendingLinesFor(
      week: long,
      width: 360,
      fontSize: 17,
      length: ReflectionLength.paragraph,
    );
    expect(shortLines, 1);
    expect(longLines, greaterThan(shortLines));
  });

  test('a larger accessibility text scale deepens the cloud with the text', () {
    final week = ReflectionWeek(
      weekStart: weekStart,
      status: ReflectionWeekStatus.reflected,
      reflection: Reflection(
        weekStart: weekStart,
        generatedAt: DateTime.utc(2026, 7, 27),
        text: 'x' * 400,
      ),
    );
    final plain = pendingLinesFor(
      week: week,
      width: 360,
      fontSize: 17,
      length: ReflectionLength.paragraph,
    );
    final scaled = pendingLinesFor(
      week: week,
      width: 360,
      fontSize: 17 * 1.6,
      length: ReflectionLength.paragraph,
    );
    expect(scaled, greaterThan(plain));
  });

  test('a week with no text falls back to the length knob', () {
    final silent = ReflectionWeek(
      weekStart: weekStart,
      status: ReflectionWeekStatus.silent,
      reflection: Reflection(weekStart: weekStart, generatedAt: DateTime.utc(2026, 7, 27)),
    );
    expect(
      pendingLinesFor(week: silent, width: 360, fontSize: 17, length: ReflectionLength.sentences),
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

  group('scrubPage', () {
    test('one pitch of travel turns one week, in the drag direction', () {
      expect(scrubPage(anchorPage: 3, dx: 26, pitch: 26, count: 10), 4);
      expect(scrubPage(anchorPage: 3, dx: -52, pitch: 26, count: 10), 1);
    });

    test('a touch without movement holds the anchor', () {
      // Responding on pointer-down must never teleport the pager.
      expect(scrubPage(anchorPage: 6.0, dx: 0, pitch: 26, count: 10), 6.0);
    });

    test('the scrub clamps at both ends of the timeline', () {
      expect(scrubPage(anchorPage: 8, dx: 1000, pitch: 26, count: 10), 9);
      expect(scrubPage(anchorPage: 1, dx: -1000, pitch: 26, count: 10), 0);
    });

    test('a timeline of one (or none) pins to the only page', () {
      expect(scrubPage(anchorPage: 0, dx: 300, pitch: 26, count: 1), 0);
      expect(scrubPage(anchorPage: 0, dx: 300, pitch: 26, count: 0), 0);
    });
  });

  group('scrubberVisible', () {
    test('a single page never shows a scrubber, whatever else is true', () {
      expect(
        scrubberVisible(count: 1, readingShown: true, pagerActive: true, scrubbing: true),
        isFalse,
      );
    });

    test('at rest it follows the reading fold', () {
      expect(
        scrubberVisible(count: 5, readingShown: true, pagerActive: false, scrubbing: false),
        isTrue,
      );
      expect(
        scrubberVisible(count: 5, readingShown: false, pagerActive: false, scrubbing: false),
        isFalse,
      );
    });

    test('a finger on the capsule overrides the fold', () {
      expect(
        scrubberVisible(count: 5, readingShown: false, pagerActive: false, scrubbing: true),
        isTrue,
      );
    });

    test('pager motion overrides the fold', () {
      expect(
        scrubberVisible(count: 5, readingShown: false, pagerActive: true, scrubbing: false),
        isTrue,
      );
    });
  });

  group('scrubberScrollFold', () {
    ({bool shown, double anchor}) fold({
      required bool shown,
      required double anchor,
      required double offset,
    }) => scrubberScrollFold(shown: shown, anchor: anchor, offset: offset, slack: 24, topBand: 32);

    test('inside the top band it always shows, even mid-hide', () {
      expect(fold(shown: false, anchor: 400, offset: 20).shown, isTrue);
      // Overscroll bounce (negative offsets) counts as the top.
      expect(fold(shown: false, anchor: 400, offset: -10).shown, isTrue);
    });

    test('a slack of downward travel hides it, and only past the slack exactly', () {
      expect(fold(shown: true, anchor: 100, offset: 120).shown, isTrue);
      // Exactly one slack of travel still shows: hiding starts PAST it.
      expect(fold(shown: true, anchor: 100, offset: 124).shown, isTrue);
      expect(fold(shown: true, anchor: 100, offset: 125).shown, isFalse);
    });

    test('a slack of upward travel brings it back, anywhere in the text', () {
      expect(fold(shown: false, anchor: 500, offset: 480).shown, isFalse);
      expect(fold(shown: false, anchor: 500, offset: 475).shown, isTrue);
    });

    test('jitter inside the slack flips nothing', () {
      var state = (shown: true, anchor: 100.0);
      for (final offset in [105.0, 98.0, 110.0, 95.0]) {
        state = fold(shown: state.shown, anchor: state.anchor, offset: offset);
        expect(state.shown, isTrue);
      }
    });

    test('the anchor ratchets to the extremum since the last flip', () {
      // Shown: the anchor chases the lowest point, so travel measures from
      // the turnaround, not from wherever the fold last ran.
      var state = fold(shown: true, anchor: 200, offset: 150);
      expect(state.anchor, 150);
      state = fold(shown: state.shown, anchor: state.anchor, offset: 170);
      expect(state.shown, isTrue);
      state = fold(shown: state.shown, anchor: state.anchor, offset: 175);
      expect(state.shown, isFalse);
    });
  });

  group('dashStripShift', () {
    test('a strip that fits never slides', () {
      expect(dashStripShift(count: 5, position: 4, max: 7), 0);
    });

    test('mid-range the viewed page rides the center, fractionally', () {
      expect(dashStripShift(count: 30, position: 15, max: 7), 12);
      expect(dashStripShift(count: 30, position: 15.5, max: 7), 12.5);
    });

    test('the strip pins at both ends', () {
      expect(dashStripShift(count: 30, position: 1, max: 7), 0);
      expect(dashStripShift(count: 30, position: 29, max: 7), 23);
    });
  });

  group('dashRimScale', () {
    test('dashes stand full size away from the rims', () {
      expect(dashRimScale(slot: 3, shift: 12, count: 30, max: 7), 1);
    });

    test('a rim with pages beyond it shrinks its dash, down to half', () {
      expect(dashRimScale(slot: 0, shift: 12, count: 30, max: 7), 0.5);
      expect(dashRimScale(slot: 0.5, shift: 12, count: 30, max: 7), 0.75);
      expect(dashRimScale(slot: 6, shift: 12, count: 30, max: 7), 0.5);
    });

    test('a pinned side stays full: nothing lies beyond it', () {
      expect(dashRimScale(slot: 0, shift: 0, count: 30, max: 7), 1);
      expect(dashRimScale(slot: 6, shift: 23, count: 30, max: 7), 1);
    });

    test('a barely overflowing strip mid-slide shrinks both rims at once', () {
      // count 8 through 7 slots at shift 0.5: pages lie beyond both rims, so
      // both ramps are live and each rim takes the smaller of the two.
      expect(dashRimScale(slot: 0, shift: 0.5, count: 8, max: 7), 0.5);
      expect(dashRimScale(slot: 6, shift: 0.5, count: 8, max: 7), 0.5);
      expect(dashRimScale(slot: 3, shift: 0.5, count: 8, max: 7), 1);
    });
  });
}
