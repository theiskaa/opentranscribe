import 'package:flutter_test/flutter_test.dart';

import 'package:opentranscribe/core/models/pane_layout.dart';
import 'package:opentranscribe/view/widgets/app_top_bar.dart';

void main() {
  test('an opened record has a split back button because it replaces the journal', () {
    expect(
      panePageShowsBack(
        mode: PaneMode.split,
        journalSelection: true,
        detailRoot: true,
        canPop: true,
      ),
      isTrue,
    );
  });

  test('a sidebar destination has no redundant split back button', () {
    expect(
      panePageShowsBack(
        mode: PaneMode.split,
        journalSelection: false,
        detailRoot: true,
        canPop: true,
      ),
      isFalse,
    );
  });

  test('a page pushed above a selected entry shows back in the detail pane', () {
    expect(panePageShowsBack(mode: PaneMode.split, journalSelection: false, canPop: true), isTrue);
  });

  test('a phone and cover keep back for journal selections and menu pages', () {
    for (final mode in [null, PaneMode.single]) {
      for (final selected in [false, true]) {
        for (final root in [false, true]) {
          expect(
            panePageShowsBack(
              mode: mode,
              journalSelection: selected,
              detailRoot: root,
              canPop: true,
            ),
            isTrue,
          );
        }
      }
    }
  });

  test('a route with nothing to return to never grows an automatic back button', () {
    for (final mode in [null, ...PaneMode.values]) {
      for (final selected in [false, true]) {
        expect(panePageShowsBack(mode: mode, journalSelection: selected, canPop: false), isFalse);
      }
    }
  });
}
