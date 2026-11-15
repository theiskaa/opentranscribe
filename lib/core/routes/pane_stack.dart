import 'package:opentranscribe/core/models/pane_layout.dart';

enum PaneTouch { journal, detail }

bool stackOnCollapse({
  required PaneMode? previousMode,
  required PaneMode mode,
  required bool settled,
  required int detailDepth,
  required bool journalTouched,
  required bool detailTouched,
  required bool covered,
}) =>
    settled &&
    previousMode == PaneMode.split &&
    mode == PaneMode.single &&
    detailDepth == 1 &&
    journalTouched &&
    !detailTouched &&
    !covered;

final class PaneStack {
  const PaneStack({
    this.settledMode,
    this.selection,
    this.journalTouched = false,
    this.detailTouched = false,
  });

  final PaneMode? settledMode;
  final Object? selection;
  final bool journalTouched;
  final bool detailTouched;

  PaneStack select(Object? key) =>
      key == selection ? this : PaneStack(settledMode: settledMode, selection: key);

  PaneStack touch(PaneTouch pane) => PaneStack(
    settledMode: settledMode,
    selection: selection,
    journalTouched: journalTouched || pane == PaneTouch.journal,
    detailTouched: detailTouched || pane == PaneTouch.detail,
  );

  PaneStack consumeCollapse() => PaneStack(
    settledMode: PaneMode.single,
    selection: selection,
    journalTouched: journalTouched,
    detailTouched: detailTouched,
  );

  ({PaneStack stack, bool popSelection}) layout({
    required PaneMode mode,
    required bool settled,
    required int detailDepth,
    required bool covered,
    bool selectionOnTop = true,
  }) {
    final collapse = stackOnCollapse(
      previousMode: settledMode,
      mode: mode,
      settled: settled,
      detailDepth: detailDepth,
      journalTouched: journalTouched,
      detailTouched: detailTouched,
      covered: covered,
    );
    return (
      stack: PaneStack(
        settledMode: settled && !collapse ? mode : settledMode,
        selection: selection,
        journalTouched: journalTouched,
        detailTouched: detailTouched,
      ),
      popSelection: collapse && selectionOnTop,
    );
  }
}
