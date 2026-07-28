import 'package:flutter_test/flutter_test.dart';

import 'package:opentranscribe/core/routes/app_router.dart';
import 'package:opentranscribe/core/routes/routes.dart';

void main() {
  group('resolveRedirect', () {
    test('an unfinished user anywhere but onboarding is sent to onboarding', () {
      expect(
        resolveRedirect(onboardingDone: false, matchedLocation: Routes.home),
        Routes.onboarding,
      );
      expect(
        resolveRedirect(onboardingDone: false, matchedLocation: '/entry/x'),
        Routes.onboarding,
      );
    });

    test('an unfinished user already at onboarding is not redirected', () {
      // Loop-freedom guarantee: redirecting here would bounce forever.
      expect(resolveRedirect(onboardingDone: false, matchedLocation: Routes.onboarding), isNull);
    });

    test('a finished user at onboarding is sent home, never back in', () {
      expect(
        resolveRedirect(onboardingDone: true, matchedLocation: Routes.onboarding),
        Routes.home,
      );
    });

    test('a finished user anywhere else is left alone', () {
      expect(resolveRedirect(onboardingDone: true, matchedLocation: Routes.home), isNull);
      expect(resolveRedirect(onboardingDone: true, matchedLocation: '/entry/x'), isNull);
    });
  });
}
