import 'package:flutter_test/flutter_test.dart';

import 'package:opentranscribe/core/routes/app_router.dart';
import 'package:opentranscribe/core/routes/routes.dart';

void main() {
  group('canOpenRecorder', () {
    test('a stack without the recorder may open it', () {
      expect(canOpenRecorder(stack: [Routes.home], onboardingDone: true), isTrue);
      expect(canOpenRecorder(stack: [Routes.home, '/entry/x'], onboardingDone: true), isTrue);
    });

    test('the recorder on top is already open', () {
      expect(canOpenRecorder(stack: [Routes.home, Routes.record], onboardingDone: true), isFalse);
    });

    test('the recorder carrying an entry query is still the recorder', () {
      expect(
        canOpenRecorder(stack: [Routes.home, '${Routes.record}?entry=x'], onboardingDone: true),
        isFalse,
      );
    });

    test('the recorder under another page is still open', () {
      expect(
        canOpenRecorder(
          stack: [Routes.home, Routes.record, Routes.settingsCache],
          onboardingDone: true,
        ),
        isFalse,
      );
    });

    test('a router with no pages yet refuses, having nothing to push over', () {
      expect(canOpenRecorder(stack: [], onboardingDone: true), isFalse);
    });

    test('an unfinished user is refused wherever they are', () {
      expect(canOpenRecorder(stack: [Routes.onboarding], onboardingDone: false), isFalse);
      expect(canOpenRecorder(stack: [Routes.home], onboardingDone: false), isFalse);
    });
  });

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

    test('a finished user reaches onboarding only as a replay', () {
      expect(
        resolveRedirect(onboardingDone: true, matchedLocation: Routes.onboarding, replay: true),
        isNull,
      );
      expect(
        resolveRedirect(onboardingDone: true, matchedLocation: Routes.onboarding),
        Routes.home,
      );
    });

    test('a replay flag buys an unfinished user nothing', () {
      expect(
        resolveRedirect(onboardingDone: false, matchedLocation: Routes.home, replay: true),
        Routes.onboarding,
      );
      expect(
        resolveRedirect(onboardingDone: false, matchedLocation: Routes.onboarding, replay: true),
        isNull,
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
