import 'package:reflections/reflections.dart';

/// Whether onboarding should pitch weekly reflections and offer the nudge on
/// this device. True for any hardware that could run reflections once Apple
/// Intelligence is set up (running, still preparing, or simply switched off),
/// false for devices that can never run them, so nothing is sold and no
/// notification permission is asked where the feature can never work.
bool reflectionsEligible(ReflectionAvailabilityStatus status) => switch (status) {
  ReflectionAvailabilityStatus.available ||
  ReflectionAvailabilityStatus.notEnabled ||
  ReflectionAvailabilityStatus.modelNotReady => true,
  ReflectionAvailabilityStatus.deviceNotEligible ||
  ReflectionAvailabilityStatus.unsupported => false,
};
