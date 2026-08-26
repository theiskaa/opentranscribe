import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/view/layouts/onboarding/components/onboarding_reflections.dart';
import 'package:reflections/reflections.dart';

void main() {
  test('reflectionsEligible is true for any hardware that could run reflections', () {
    for (final status in const [
      ReflectionAvailabilityStatus.available,
      ReflectionAvailabilityStatus.notEnabled,
      ReflectionAvailabilityStatus.modelNotReady,
    ]) {
      expect(reflectionsEligible(status), isTrue, reason: '$status');
    }
  });

  test('reflectionsEligible is false where reflections can never run', () {
    for (final status in const [
      ReflectionAvailabilityStatus.deviceNotEligible,
      ReflectionAvailabilityStatus.unsupported,
    ]) {
      expect(reflectionsEligible(status), isFalse, reason: '$status');
    }
  });
}
