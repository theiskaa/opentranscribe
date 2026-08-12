import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/models/reflection.dart';
import 'package:opentranscribe/core/models/reflection_timeline.dart';
import 'package:opentranscribe/view/layouts/reflections/components/reflection_page_logic.dart';
import 'package:opentranscribe/view/widgets/ink_reveal.dart';
import 'package:reflections/reflections.dart';

void main() {
  final periodStart = DateTime(2026, 7, 20);

  ReflectionPage reflected({DateTime? generatedAt}) => ReflectionPage(
    periodStart: periodStart,
    status: ReflectionPageStatus.reflected,
    reflection: Reflection(
      periodStart: periodStart,
      generatedAt: generatedAt ?? DateTime.utc(2026, 7, 27),
      text: 'a week',
    ),
  );

  InkPhase phaseFor(
    ReflectionPage week, {
    bool regenerating = false,
    bool held = false,
    Set<String> revealed = const {},
  }) => inkPhaseFor(page: week, regenerating: regenerating, held: held, revealed: revealed);

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

  test('a hold renders an unrevealed week settled, so flying past starts no write', () {
    expect(phaseFor(reflected(), held: true), InkPhase.settled);
  });

  test('a regenerating week stays pending under a hold', () {
    expect(phaseFor(reflected(), regenerating: true, held: true), InkPhase.pending);
  });

  test('a regenerate changes the ledger key, so the new words re-arrive', () {
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

  test('a regenerate cloud is shaped like the text it replaces, not the knob\'s fixed height', () {
    final short = ReflectionPage(
      periodStart: periodStart,
      status: ReflectionPageStatus.reflected,
      reflection: Reflection(
        periodStart: periodStart,
        generatedAt: DateTime.utc(2026, 7, 27),
        text: 'One brief line.',
      ),
    );
    final long = ReflectionPage(
      periodStart: periodStart,
      status: ReflectionPageStatus.reflected,
      reflection: Reflection(
        periodStart: periodStart,
        generatedAt: DateTime.utc(2026, 7, 27),
        text: 'x' * 400,
      ),
    );
    final shortLines = pendingLinesFor(
      page: short,
      width: 360,
      fontSize: 17,
      length: ReflectionLength.paragraph,
    );
    final longLines = pendingLinesFor(
      page: long,
      width: 360,
      fontSize: 17,
      length: ReflectionLength.paragraph,
    );
    expect(shortLines, 1);
    expect(longLines, greaterThan(shortLines));
  });

  test('a larger accessibility text scale deepens the cloud with the text', () {
    final week = ReflectionPage(
      periodStart: periodStart,
      status: ReflectionPageStatus.reflected,
      reflection: Reflection(
        periodStart: periodStart,
        generatedAt: DateTime.utc(2026, 7, 27),
        text: 'x' * 400,
      ),
    );
    final plain = pendingLinesFor(
      page: week,
      width: 360,
      fontSize: 17,
      length: ReflectionLength.paragraph,
    );
    final scaled = pendingLinesFor(
      page: week,
      width: 360,
      fontSize: 17 * 1.6,
      length: ReflectionLength.paragraph,
    );
    expect(scaled, greaterThan(plain));
  });

  test('a week with no text falls back to the length knob', () {
    final silent = ReflectionPage(
      periodStart: periodStart,
      status: ReflectionPageStatus.silent,
      reflection: Reflection(periodStart: periodStart, generatedAt: DateTime.utc(2026, 7, 27)),
    );
    expect(
      pendingLinesFor(page: silent, width: 360, fontSize: 17, length: ReflectionLength.sentences),
      placeholderLinesFor(ReflectionLength.sentences),
    );
  });

  group('eagerPageTarget', () {
    test('a short drag commits once it clears the threshold, either way', () {
      expect(eagerPageTarget(page: 3.25, from: 3, flick: 0), 4);
      expect(eagerPageTarget(page: 2.75, from: 3, flick: 0), 2);
    });

    test('exactly at the threshold the page springs home, checked at a binary-exact 0.25 '
        'so the strict comparison is the rule under test, not float noise', () {
      expect(eagerPageTarget(page: 3.25, from: 3, flick: 0, threshold: 0.25), 3);
      expect(eagerPageTarget(page: 2.75, from: 3, flick: 0, threshold: 0.25), 3);
    });

    test('a graze under the threshold still springs home despite the eager commit', () {
      expect(eagerPageTarget(page: 3.1, from: 3, flick: 0), 3);
      expect(eagerPageTarget(page: 2.9, from: 3, flick: 0), 3);
    });

    test('any flick commits in its direction regardless of distance', () {
      expect(eagerPageTarget(page: 3.05, from: 3, flick: 1), 4);
      expect(eagerPageTarget(page: 2.95, from: 3, flick: -1), 2);
    });

    test('a stale anchor from a swipe still settling re-anchors to the nearest page '
        'instead of dragging the target back', () {
      expect(eagerPageTarget(page: 4.3, from: 3, flick: 0), 5);
      expect(eagerPageTarget(page: 4.1, from: 3, flick: 0), 4);
    });
  });

  group('scrubPage', () {
    test('one pitch of travel turns one week, in the drag direction', () {
      expect(scrubPage(anchorPage: 3, dx: 26, pitch: 26, count: 10), 4);
      expect(scrubPage(anchorPage: 3, dx: -52, pitch: 26, count: 10), 1);
    });

    test(
      'a touch without movement holds the anchor, so pointer-down never teleports the pager',
      () {
        expect(scrubPage(anchorPage: 6.0, dx: 0, pitch: 26, count: 10), 6.0);
      },
    );

    test('the scrub clamps at both ends of the timeline', () {
      expect(scrubPage(anchorPage: 8, dx: 1000, pitch: 26, count: 10), 9);
      expect(scrubPage(anchorPage: 1, dx: -1000, pitch: 26, count: 10), 0);
    });

    test('a timeline of one (or none) pins to the only page', () {
      expect(scrubPage(anchorPage: 0, dx: 300, pitch: 26, count: 1), 0);
      expect(scrubPage(anchorPage: 0, dx: 300, pitch: 26, count: 0), 0);
    });
  });

  group('scrubTapTarget', () {
    test('the right half turns one week newer, the left half one older', () {
      expect(scrubTapTarget(page: 3, dx: 80, width: 100, count: 10), 4);
      expect(scrubTapTarget(page: 3, dx: 20, width: 100, count: 10), 2);
    });

    test('the exact middle counts as the right half', () {
      expect(scrubTapTarget(page: 3, dx: 50, width: 100, count: 10), 4);
    });

    test('a tap at either end of the timeline stays in range', () {
      expect(scrubTapTarget(page: 0, dx: 10, width: 100, count: 10), 0);
      expect(scrubTapTarget(page: 9, dx: 90, width: 100, count: 10), 9);
    });

    test('a timeline of one (or none) pins to the only page', () {
      expect(scrubTapTarget(page: 0, dx: 90, width: 100, count: 1), 0);
      expect(scrubTapTarget(page: 0, dx: 90, width: 100, count: 0), 0);
    });
  });

  group('tapChainBase', () {
    test('with nothing in flight the live rounding is the base', () {
      expect(tapChainBase(page: 3.0, pending: null), 3);
      expect(tapChainBase(page: 3.6, pending: null), 4);
    });

    test('an unfinished turn chains from its own target, not from re-rounding the transfer', () {
      expect(tapChainBase(page: 3.3, pending: 4), 4);
      expect(tapChainBase(page: 4.7, pending: 4), 4);
    });

    test('a pending target left far behind by another motion is stale, so the rounding wins', () {
      expect(tapChainBase(page: 6.0, pending: 4), 6);
      expect(tapChainBase(page: 1.4, pending: 4), 1);
    });

    test('the staleness boundary pins where chaining gives way to the live page', () {
      expect(tapChainBase(page: 5.1, pending: 4), 4);
      expect(tapChainBase(page: 5.3, pending: 4), 5);
      expect(tapChainBase(page: 2.9, pending: 4), 4);
      expect(tapChainBase(page: 2.7, pending: 4), 3);
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

    test('inside the top band it always shows, even mid-hide, '
        'and overscroll bounce counts as the top', () {
      expect(fold(shown: false, anchor: 400, offset: 20).shown, isTrue);
      expect(fold(shown: false, anchor: 400, offset: -10).shown, isTrue);
    });

    test('a slack of downward travel hides it, and only past the slack exactly', () {
      expect(fold(shown: true, anchor: 100, offset: 120).shown, isTrue);
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

    test('the anchor ratchets to the extremum since the last flip, '
        'so travel measures from the turnaround', () {
      var state = fold(shown: true, anchor: 200, offset: 150);
      expect(state.anchor, 150);
      state = fold(shown: state.shown, anchor: state.anchor, offset: 170);
      expect(state.shown, isTrue);
      state = fold(shown: state.shown, anchor: state.anchor, offset: 175);
      expect(state.shown, isFalse);
    });
  });

  group('stripShift', () {
    test('a strip that fits never slides', () {
      expect(stripShift(count: 5, position: 4, max: 7), 0);
    });

    test('mid-range the viewed page rides the center, fractionally', () {
      expect(stripShift(count: 30, position: 15, max: 7), 12);
      expect(stripShift(count: 30, position: 15.5, max: 7), 12.5);
    });

    test('the strip pins at both ends', () {
      expect(stripShift(count: 30, position: 1, max: 7), 0);
      expect(stripShift(count: 30, position: 29, max: 7), 23);
    });
  });

  group('rimScale', () {
    test('dots stand full size away from the rims', () {
      expect(rimScale(slot: 3, shift: 12, count: 30, max: 7), 1);
    });

    test('a rim with pages beyond it shrinks its dot, down to half', () {
      expect(rimScale(slot: 0, shift: 12, count: 30, max: 7), 0.5);
      expect(rimScale(slot: 0.5, shift: 12, count: 30, max: 7), 0.75);
      expect(rimScale(slot: 6, shift: 12, count: 30, max: 7), 0.5);
    });

    test('a pinned side stays full: nothing lies beyond it', () {
      expect(rimScale(slot: 0, shift: 0, count: 30, max: 7), 1);
      expect(rimScale(slot: 6, shift: 23, count: 30, max: 7), 1);
    });

    test('a barely overflowing strip mid-slide shrinks both rims at once, '
        'each taking the smaller of the two live ramps', () {
      expect(rimScale(slot: 0, shift: 0.5, count: 8, max: 7), 0.5);
      expect(rimScale(slot: 6, shift: 0.5, count: 8, max: 7), 0.5);
      expect(rimScale(slot: 3, shift: 0.5, count: 8, max: 7), 1);
    });
  });

  group('bridge transfer', () {
    test('the stream is absent at either rest and strongest mid-transfer, symmetrically', () {
      expect(bridgeNeck(0), 0);
      expect(bridgeNeck(1), closeTo(0, 1e-9));
      expect(bridgeNeck(0.5), 1);
      expect(bridgeNeck(0.2), closeTo(bridgeNeck(0.8), 1e-9));
    });

    test('the source blob is full at rest and only ever drains as the ink flows over', () {
      expect(bridgeDrain(0), 1);
      expect(bridgeDrain(0.3), lessThan(1));
      expect(bridgeDrain(0.92), closeTo(0, 1e-9));
      expect(bridgeDrain(1), 0);
      var previous = 2.0;
      for (var t = 0.0; t <= 1.0; t += 0.05) {
        final drain = bridgeDrain(t);
        expect(drain, lessThanOrEqualTo(previous));
        previous = drain;
      }
    });

    test('the destination fills as the source drains, swells past full, '
        'and settles exactly full at rest', () {
      expect(bridgeFill(0), 0);
      expect(bridgeFill(0.08), 0);
      expect(bridgeFill(1), closeTo(1, 1e-9));
      var peak = 0.0;
      for (var t = 0.0; t <= 1.0; t += 0.01) {
        peak = math.max(peak, bridgeFill(t));
      }
      expect(peak, greaterThan(1));
      expect(peak, lessThan(1.25));
    });

    test('some ink is always visible across the whole transfer', () {
      for (var t = 0.0; t <= 1.0; t += 0.02) {
        final visible = bridgeDrain(t) + bridgeFill(t);
        expect(visible, greaterThan(0.5), reason: 't=$t');
      }
    });

    test('mid-transfer both blobs stand, so the stream always has two ends to pinch between', () {
      for (var t = 0.25; t <= 0.75; t += 0.05) {
        expect(bridgeDrain(t), greaterThan(0.05), reason: 't=$t');
        expect(bridgeFill(t), greaterThan(0.05), reason: 't=$t');
      }
    });

    test('out-of-range input clamps to the resting poses, never overshooting', () {
      expect(bridgeDrain(-0.2), 1);
      expect(bridgeFill(-0.2), 0);
      expect(bridgeNeck(-0.2), 0);
      expect(bridgeDrain(1.5), 0);
      expect(bridgeFill(1.5), closeTo(1, 1e-9));
      expect(bridgeNeck(1.5), closeTo(0, 1e-9));
    });

    test('the ink handed off at a dot matches the next transfer\'s source, so no pop', () {
      expect(bridgeFill(1), closeTo(bridgeDrain(0), 1e-9));
      expect(bridgeNeck(1), closeTo(bridgeNeck(0), 1e-9));
    });
  });
}
