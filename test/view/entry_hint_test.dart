import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/view/layouts/entry/screens/entry_detail_screen.dart';

void main() {
  test('an unseen hint shows on a quiet entry', () {
    expect(shouldShowEntryHint(seen: false, editing: false, busy: false), isTrue);
  });

  test('a seen hint never shows again', () {
    expect(shouldShowEntryHint(seen: true, editing: false, busy: false), isFalse);
  });

  test('the hint waits while the menu it points at is hidden or thinned', () {
    expect(shouldShowEntryHint(seen: false, editing: true, busy: false), isFalse);
    expect(shouldShowEntryHint(seen: false, editing: false, busy: true), isFalse);
  });
}
