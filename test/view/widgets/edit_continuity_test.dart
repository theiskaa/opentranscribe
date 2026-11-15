import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';

import 'package:opentranscribe/view/widgets/edit_continuity.dart';

EditRestore decision({
  bool supported = true,
  bool settled = true,
  bool stable = true,
  bool currentRoute = true,
  bool canFocus = true,
  bool anotherFieldFocused = false,
  bool interrupted = false,
  String savedText = 'Unsaved words',
  String currentText = 'Unsaved words',
}) => editRestoreFor(
  supported: supported,
  settled: settled,
  stable: stable,
  currentRoute: currentRoute,
  canFocus: canFocus,
  anotherFieldFocused: anotherFieldFocused,
  interrupted: interrupted,
  savedText: savedText,
  currentText: currentText,
);

void main() {
  test('the cover remains known through a stale cover-to-inner frame', () {
    final coverKnown = editDisplayKnown(
      previouslyKnown: false,
      supported: true,
      cover: true,
      regular: false,
    );
    expect(coverKnown, isTrue);
    expect(
      editDisplayKnown(previouslyKnown: coverKnown, supported: true, cover: false, regular: false),
      isTrue,
    );
  });

  test('a cold inner display is known and a regular compact phone is not', () {
    expect(
      editDisplayKnown(previouslyKnown: false, supported: true, cover: false, regular: true),
      isTrue,
    );
    expect(
      editDisplayKnown(previouslyKnown: false, supported: true, cover: false, regular: false),
      isFalse,
    );
    expect(
      editDisplayKnown(previouslyKnown: false, supported: false, cover: false, regular: true),
      isFalse,
    );
  });

  test('an unchanged edit restores after a settled frame', () {
    expect(decision(), EditRestore.restore);
  });

  test('a stale display signal waits without committing or restoring the edit', () {
    expect(decision(settled: false), EditRestore.wait);
  });

  test('a newly settled size waits until a frame has passed at that size', () {
    expect(decision(stable: false), EditRestore.wait);
  });

  test('a regular phone never requests display recovery', () {
    expect(decision(supported: false), EditRestore.discard);
  });

  test('a covered or departed editor cannot steal focus back', () {
    expect(decision(currentRoute: false), EditRestore.discard);
    expect(decision(anotherFieldFocused: true), EditRestore.discard);
    expect(decision(canFocus: false), EditRestore.discard);
  });

  test('an intentional interaction cancels recovery even while the signal is stale', () {
    expect(decision(interrupted: true, settled: false), EditRestore.discard);
  });

  test('newer typing is never replaced with the saved edit', () {
    expect(decision(currentText: 'Unsaved words and more'), EditRestore.discard);
  });

  test('an empty title or passphrase remains a valid in-progress edit', () {
    expect(decision(savedText: '', currentText: ''), EditRestore.restore);
  });
  test('a backwards selection keeps its direction and affinity', () {
    const selection = TextSelection(
      baseOffset: 9,
      extentOffset: 3,
      affinity: TextAffinity.upstream,
      isDirectional: true,
    );
    expect(editSelectionFor(selection, 12), selection);
  });

  test('a caret at the end of an empty field is restored', () {
    const selection = TextSelection.collapsed(offset: 0);
    expect(editSelectionFor(selection, 0), selection);
  });

  test('invalid and out-of-range carets are never assigned to the controller', () {
    expect(editSelectionFor(const TextSelection.collapsed(offset: -1), 12), isNull);
    expect(editSelectionFor(const TextSelection(baseOffset: 2, extentOffset: 13), 12), isNull);
  });
}
