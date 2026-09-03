import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/view/layouts/onboarding/components/onboarding_setup.dart';

void main() {
  test('a loaded default draws its live row, whatever the last load did', () {
    expect(languageRowFace(hasRow: true, loadFailed: false), LanguageRowFace.live);
    expect(languageRowFace(hasRow: true, loadFailed: true), LanguageRowFace.live);
  });

  test('no row yet waits on the load', () {
    expect(languageRowFace(hasRow: false, loadFailed: false), LanguageRowFace.loading);
  });

  test('a failed load with no row names the default instead of waiting forever', () {
    expect(languageRowFace(hasRow: false, loadFailed: true), LanguageRowFace.nameOnly);
  });
}
