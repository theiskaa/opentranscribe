import 'package:flutter_test/flutter_test.dart';
import 'package:liquid/liquid.dart';

void main() {
  group('LiquidPopupButton menu identity', () {
    test('a value repeated across the tree throws in debug mode', () {
      expect(
        () => LiquidPopupButton(
          items: const [
            LiquidPopupButtonEntry(value: 'dup', label: 'A'),
            LiquidPopupButtonEntry(value: 'dup', label: 'B'),
          ],
        ),
        throwsAssertionError,
      );
    });

    test('a top-level keepsPresented entry throws in debug mode', () {
      expect(
        () => LiquidPopupButton(
          items: const [LiquidPopupButtonEntry(value: 'a', label: 'A', keepsPresented: true)],
        ),
        throwsAssertionError,
      );
    });
  });
}
