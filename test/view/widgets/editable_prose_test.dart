import 'package:flutter/services.dart' show SelectionChangedCause;
import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/view/widgets/editable_prose.dart';

void main() {
  bool shows({
    SelectionChangedCause? cause = SelectionChangedCause.longPress,
    bool collapsed = false,
    bool hasText = true,
    bool gestureAllows = true,
  }) => showsSelectionHandles(
    cause: cause,
    collapsed: collapsed,
    hasText: hasText,
    gestureAllows: gestureAllows,
  );

  group('showsSelectionHandles', () {
    test('a long press over text shows them', () {
      expect(shows(), isTrue);
    });

    test('a collapsed selection never shows them', () {
      expect(shows(collapsed: true), isFalse);
    });

    test('a selection the keyboard made never shows them', () {
      expect(shows(cause: SelectionChangedCause.keyboard), isFalse);
    });

    test('handwriting always shows them, even over an empty field', () {
      expect(shows(cause: SelectionChangedCause.stylusHandwriting, hasText: false), isTrue);
    });

    test('an empty field shows none', () {
      expect(shows(hasText: false), isFalse);
    });

    test('a gesture that raised no toolbar shows none', () {
      expect(shows(gestureAllows: false), isFalse);
    });
  });
}
