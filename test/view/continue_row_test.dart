import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/view/layouts/entry/screens/entry_detail_screen.dart';

void main() {
  test('the continue row shows only for kept audio with no edit and no run in flight', () {
    expect(continueRowVisible(hasAudio: true, editing: false, busy: false), isTrue);
    expect(continueRowVisible(hasAudio: false, editing: false, busy: false), isFalse);
    expect(continueRowVisible(hasAudio: true, editing: true, busy: false), isFalse);
    expect(continueRowVisible(hasAudio: true, editing: false, busy: true), isFalse);
  });
}
