import 'package:flutter_test/flutter_test.dart';

import 'package:opentranscribe/view/widgets/reflow_anchor.dart';

void main() {
  const narrow = <ReflowLine>[
    (start: 0, end: 10, top: 0, height: 20),
    (start: 10, end: 20, top: 20, height: 20),
    (start: 20, end: 30, top: 40, height: 20),
    (start: 30, end: 40, top: 60, height: 20),
  ];
  const wide = <ReflowLine>[
    (start: 0, end: 20, top: 0, height: 24),
    (start: 20, end: 40, top: 24, height: 24),
  ];

  test('a partly hidden line keeps its character and hidden fraction after widening', () {
    final anchor = anchorAt(narrow, 45)!;
    expect(anchor, (character: 20, fraction: 0.25));
    expect(offsetFor(wide, anchor), 30);
  });

  test('narrowing restores the line containing the old first character', () {
    final anchor = anchorAt(wide, 36)!;
    expect(offsetFor(narrow, anchor), 50);
  });

  test('a character exactly on a line boundary belongs to the following line', () {
    expect(offsetFor(narrow, (character: 20, fraction: 0)), 40);
    expect(anchorAt(narrow, 20), (character: 10, fraction: 0.0));
  });

  test('a reading line outside the prose leaves the scroll alone', () {
    expect(anchorAt(narrow, -1), isNull);
    expect(anchorAt(narrow, 80), isNull);
    expect(anchorAt([], 0), isNull);
    expect(offsetFor([], (character: 0, fraction: 0)), isNull);
  });

  test('a shortened document restores within its final line', () {
    expect(offsetFor(wide, (character: 80, fraction: 0.5)), 36);
  });

  test('a blank line between paragraphs remains the reading anchor', () {
    const lines = <ReflowLine>[
      (start: 0, end: 9, top: 0, height: 20),
      (start: 10, end: 10, top: 20, height: 20),
      (start: 11, end: 20, top: 40, height: 20),
    ];
    expect(offsetFor(lines, anchorAt(lines, 25)!), 25);
  });

  test('an unchanged width returns the original reading position', () {
    for (final top in [0.0, 19.0, 20.0, 37.5, 79.0]) {
      expect(offsetFor(narrow, anchorAt(narrow, top)!), top);
    }
  });

  test('stale frames keep the original anchor until one settled restore', () {
    final original = anchorAt(narrow, 45)!;
    ReadingAnchor? pending = original;
    final jumps = <double>[];
    for (final settled in [false, false, true, true]) {
      final decision = reflowAnchorFor(supported: true, settled: settled, pending: pending);
      pending = decision.pending;
      if (!settled) expect(pending, original);
      final anchor = decision.restore;
      if (anchor != null) jumps.add(offsetFor(wide, anchor)!);
    }
    expect(jumps, [30]);
    expect(pending, isNull);
  });

  test('a settled layout without a width change never jumps', () {
    final decision = reflowAnchorFor(supported: true, settled: true, pending: null);
    expect(decision.pending, isNull);
    expect(decision.restore, isNull);
  });

  test('a regular iPhone never jumps with supported or unsupported display signals', () {
    for (final supported in [false, true]) {
      for (final settled in [false, true]) {
        final decision = reflowAnchorFor(supported: supported, settled: settled, pending: null);
        expect(decision.pending, isNull);
        expect(decision.restore, isNull);
      }
    }
  });

  test('an unsupported display discards any pending anchor without jumping', () {
    for (final settled in [false, true]) {
      for (final pending in [null, anchorAt(narrow, 45)]) {
        final decision = reflowAnchorFor(supported: false, settled: settled, pending: pending);
        expect(decision.pending, isNull);
        expect(decision.restore, isNull);
      }
    }
  });
}
