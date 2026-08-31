import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/view/layouts/entry/screens/entry_detail_screen.dart';

void main() {
  test('the continue row shows whenever no edit is open and no run is in flight', () {
    expect(continueRowVisible(editing: false, busy: false), isTrue);
    expect(continueRowVisible(editing: true, busy: false), isFalse);
    expect(continueRowVisible(editing: false, busy: true), isFalse);
  });
}
