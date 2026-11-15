import 'package:flutter_test/flutter_test.dart';

import 'package:opentranscribe/core/models/pane_layout.dart';
import 'package:opentranscribe/view/layouts/home/components/journal_chrome.dart';

void main() {
  test('a wide single inner layout shows Record in its column unless Done or a route owns it', () {
    for (final mode in PaneMode.values) {
      for (final covered in [false, true]) {
        for (final editing in [false, true]) {
          expect(
            journalRecordVisible(
              mode: mode,
              column: true,
              covered: covered,
              bottomSlotOccupied: editing,
            ),
            !covered && !editing,
          );
        }
      }
    }
  });

  test('split Record yields to Done even without a software keyboard', () {
    expect(
      journalRecordVisible(mode: PaneMode.split, covered: false, bottomSlotOccupied: true),
      isFalse,
    );
  });

  test('split Record returns when the editor releases the bottom slot', () {
    expect(
      journalRecordVisible(mode: PaneMode.split, covered: false, bottomSlotOccupied: false),
      isTrue,
    );
  });

  test('covering routes hide split Record even when the slot is free', () {
    expect(
      journalRecordVisible(mode: PaneMode.split, covered: true, bottomSlotOccupied: false),
      isFalse,
    );
  });

  test('single layouts keep the persistent split control hidden while editing or reading', () {
    for (final occupied in [false, true]) {
      expect(
        journalRecordVisible(mode: PaneMode.single, covered: false, bottomSlotOccupied: occupied),
        isFalse,
      );
    }
  });

  test('the cover shows Record on home and hides it on a detail page', () {
    for (final detail in [false, true]) {
      expect(
        journalRecordVisible(
          mode: PaneMode.single,
          column: true,
          cover: true,
          detail: detail,
          covered: false,
          bottomSlotOccupied: false,
        ),
        !detail,
      );
    }
  });

  test('an inner detail keeps Record available when Done has released its slot', () {
    expect(
      journalRecordVisible(
        mode: PaneMode.split,
        column: true,
        detail: true,
        covered: false,
        bottomSlotOccupied: false,
      ),
      isTrue,
    );
  });
}
