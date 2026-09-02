import 'package:flutter_test/flutter_test.dart';

import 'package:opentranscribe/view/widgets/app_sheet.dart';

void main() {
  test('a sheet rises with the keyboard as it opens', () {
    expect(heldKeyboardInset(inset: 0, held: 0, settled: false), 0);
    expect(heldKeyboardInset(inset: 180, held: 0, settled: false), 180);
    expect(heldKeyboardInset(inset: 336, held: 180, settled: false), 336);
  });

  test('a sheet holds its height through an input view tearing down', () {
    expect(heldKeyboardInset(inset: 0, held: 336, settled: false), 336);
    expect(heldKeyboardInset(inset: 291, held: 336, settled: false), 336);
  });

  test('a drop that outlasts the teardown takes the sheet down with it', () {
    expect(heldKeyboardInset(inset: 200, held: 336, settled: true), 200);
    expect(heldKeyboardInset(inset: 0, held: 336, settled: true), 0);
  });

  test('a settled height the keyboard grows past is given up at once', () {
    expect(heldKeyboardInset(inset: 336, held: 200, settled: false), 336);
    expect(heldKeyboardInset(inset: 336, held: 336, settled: true), 336);
  });

  test('a drop that keeps falling arms its settle', () {
    expect(settleArmed(inset: 0, held: 336, previous: 336), isTrue);
    expect(settleArmed(inset: 100, held: 336, previous: 291), isTrue);
  });

  test('an inset climbing back stands the settle down', () {
    expect(settleArmed(inset: 100, held: 336, previous: 0), isFalse);
    expect(settleArmed(inset: 291, held: 336, previous: 100), isFalse);
  });

  test('an inset at or above what the panel holds never arms a settle', () {
    expect(settleArmed(inset: 336, held: 336, previous: 336), isFalse);
    expect(settleArmed(inset: 400, held: 336, previous: 336), isFalse);
    expect(settleArmed(inset: 0, held: 0, previous: 0), isFalse);
  });

  test('re-reading the held inset every build never compounds', () {
    var held = 336.0;
    for (var i = 0; i < 5; i++) {
      held = heldKeyboardInset(inset: 291, held: held, settled: false);
    }
    expect(held, 336);
    expect(heldKeyboardInset(inset: 291, held: held, settled: true), 291);
  });
}
