import 'package:reflections/reflections.dart';

/// The pages of onboarding, in order.
enum OnboardingStep { record, reflect, shape, setup }

/// The flow for this device: the reflections page only where the hardware
/// could run them. The last step is always [OnboardingStep.setup], whose
/// button fires the permission prompts on the way in.
List<OnboardingStep> onboardingSteps({required bool canReflect}) => [
  OnboardingStep.record,
  if (canReflect) OnboardingStep.reflect,
  OnboardingStep.shape,
  OnboardingStep.setup,
];

/// Whether onboarding may pitch reflections on this device: any hardware that
/// could run them once Apple Intelligence is set up (running, still preparing,
/// or switched off). Devices that can never run them skip the page rather than
/// read an apology.
bool reflectionsEligible(ReflectionAvailabilityStatus status) => switch (status) {
  ReflectionAvailabilityStatus.available ||
  ReflectionAvailabilityStatus.notEnabled ||
  ReflectionAvailabilityStatus.modelNotReady => true,
  ReflectionAvailabilityStatus.deviceNotEligible ||
  ReflectionAvailabilityStatus.unsupported => false,
};
