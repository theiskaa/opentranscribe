import 'package:flutter_test/flutter_test.dart';

import 'package:opentranscribe/core/models/pane_layout.dart';
import 'package:opentranscribe/core/routes/pane_stack.dart';

({PaneStack stack, bool popSelection}) collapse(
  PaneStack stack, {
  bool settled = true,
  int depth = 1,
  bool covered = false,
  bool selectionOnTop = true,
}) => stack.layout(
  mode: PaneMode.single,
  settled: settled,
  detailDepth: depth,
  covered: covered,
  selectionOnTop: selectionOnTop,
);

void main() {
  const opened = PaneStack(settledMode: PaneMode.split, selection: 'entry/a');

  test('an untouched detail stays on top when closing', () {
    expect(collapse(opened).popSelection, isFalse);
  });

  test('touching only the journal returns to the journal', () {
    expect(collapse(opened.touch(PaneTouch.journal)).popSelection, isTrue);
  });

  test('touching the detail at any time keeps it even after touching the journal', () {
    final read = opened.touch(PaneTouch.detail).touch(PaneTouch.journal);
    expect(collapse(read).popSelection, isFalse);
  });

  test('touching the detail after the journal keeps it', () {
    final read = opened.touch(PaneTouch.journal).touch(PaneTouch.detail);
    expect(collapse(read).popSelection, isFalse);
  });

  test('a stale single frame neither pops nor consumes a settled collapse', () {
    final journal = opened.touch(PaneTouch.journal);
    final stale = collapse(journal, settled: false);
    expect(stale.popSelection, isFalse);
    expect(stale.stack.settledMode, PaneMode.split);
    expect(collapse(stale.stack).popSelection, isTrue);
  });

  test('a settled collapse is consumed exactly once', () {
    final first = collapse(opened.touch(PaneTouch.journal));
    expect(first.popSelection, isTrue);
    expect(collapse(first.stack.consumeCollapse()).popSelection, isFalse);
  });

  test('a dialog defers a collapse until the selection is on top', () {
    final journal = opened.touch(PaneTouch.journal);
    final blocked = collapse(journal, selectionOnTop: false);
    expect(blocked.popSelection, isFalse);
    expect(blocked.stack.settledMode, PaneMode.split);
    final ready = collapse(blocked.stack);
    expect(ready.popSelection, isTrue);
    expect(collapse(ready.stack.consumeCollapse()).popSelection, isFalse);
  });

  test('an unperformed pop does not consume the collapse decision', () {
    final first = collapse(opened.touch(PaneTouch.journal));
    final blocked = collapse(first.stack, selectionOnTop: false);
    expect(blocked.popSelection, isFalse);
    expect(collapse(blocked.stack).popSelection, isTrue);
  });

  test('reopening while a dialog blocks a collapse cancels the pending pop', () {
    final blocked = collapse(opened.touch(PaneTouch.journal), selectionOnTop: false);
    final wide = blocked.stack.layout(
      mode: PaneMode.split,
      settled: true,
      detailDepth: 1,
      covered: false,
      selectionOnTop: false,
    );
    expect(wide.popSelection, isFalse);
    expect(wide.stack.settledMode, PaneMode.split);
  });

  test('replacing a selection clears the previous selection touches', () {
    final next = opened.touch(PaneTouch.journal).select('entry/b');
    expect(next.selection, 'entry/b');
    expect(collapse(next).popSelection, isFalse);
  });

  test('updating the same selection retains its touches', () {
    final same = opened.touch(PaneTouch.journal).select('entry/a');
    expect(collapse(same).popSelection, isTrue);
  });

  test('menu pages above a selection preserve the pushed stack', () {
    expect(collapse(opened.touch(PaneTouch.journal), depth: 3).popSelection, isFalse);
  });

  test('the recorder over a selection prevents an automatic pop', () {
    expect(collapse(opened.touch(PaneTouch.journal), covered: true).popSelection, isFalse);
  });

  test('home alone has no provisional route to pop', () {
    expect(collapse(opened.select(null).touch(PaneTouch.journal), depth: 0).popSelection, isFalse);
  });

  test('a stale single frame followed by split never collapses the selection', () {
    final stale = collapse(opened.touch(PaneTouch.journal), settled: false);
    final wide = stale.stack.layout(
      mode: PaneMode.split,
      settled: true,
      detailDepth: 1,
      covered: false,
    );
    expect(wide.popSelection, isFalse);
    expect(wide.stack.settledMode, PaneMode.split);
  });
}
