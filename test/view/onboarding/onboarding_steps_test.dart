import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/view/layouts/onboarding/components/onboarding_steps.dart';
import 'package:reflections/reflections.dart';

void main() {
  test('eligible hardware gets the reflections page second', () {
    expect(onboardingSteps(canReflect: true), [
      OnboardingStep.record,
      OnboardingStep.reflect,
      OnboardingStep.shape,
      OnboardingStep.setup,
    ]);
  });

  test('other hardware skips it and the flow is three pages, set-up still last', () {
    expect(onboardingSteps(canReflect: false), [
      OnboardingStep.record,
      OnboardingStep.shape,
      OnboardingStep.setup,
    ]);
  });

  test('any hardware that could run reflections, set up or not, is eligible for the page', () {
    for (final status in const [
      ReflectionAvailabilityStatus.available,
      ReflectionAvailabilityStatus.notEnabled,
      ReflectionAvailabilityStatus.modelNotReady,
    ]) {
      expect(reflectionsEligible(status), isTrue, reason: '$status');
    }
  });

  test('hardware that can never run reflections is not', () {
    for (final status in const [
      ReflectionAvailabilityStatus.deviceNotEligible,
      ReflectionAvailabilityStatus.unsupported,
    ]) {
      expect(reflectionsEligible(status), isFalse, reason: '$status');
    }
  });
}
