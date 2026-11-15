import 'package:flutter_test/flutter_test.dart';

import 'package:opentranscribe/core/models/pane_layout.dart';
import 'package:opentranscribe/view/layouts/home/components/journal_chrome.dart';

void main() {
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
}
