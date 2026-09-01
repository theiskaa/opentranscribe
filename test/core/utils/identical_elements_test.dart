import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/utils/identical_elements.dart';

void main() {
  test('a list compares equal to itself', () {
    final list = [Object()];

    expect(identicalElements(list, list), isTrue);
  });

  test('two lists holding the same objects compare equal', () {
    final a = Object();
    final b = Object();

    expect(identicalElements([a, b], [a, b]), isTrue);
  });

  test('two empty lists compare equal', () {
    expect(identicalElements(<Object>[], <Object>[]), isTrue);
  });

  test('a differing element, order, or length compares unequal', () {
    final a = Object();
    final b = Object();

    expect(identicalElements([a, b], [b, a]), isFalse);
    expect(identicalElements([a], [a, b]), isFalse);
    expect(identicalElements([a], [Object()]), isFalse);
  });

  test('equal but distinct objects are not the same element', () {
    final a = DateTime(2026, 3, 4);
    final b = DateTime(2026, 3, 4);

    expect(a == b, isTrue);
    expect(identicalElements([a], [b]), isFalse);
  });
}
