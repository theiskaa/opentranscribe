import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:opentranscribe/core/routes/app_router.dart';
import 'package:opentranscribe/core/routes/routes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('nested routes', () {
    late GoRouter router;

    setUp(() => router = AppRouter(onboardingDone: () => true).config);
    tearDown(() => router.dispose());

    test('every detail deep entry includes home at its unchanged path', () {
      for (final path in [
        '/entry/a',
        Routes.reflections,
        Routes.settingsModels,
        Routes.settingsAppearance,
        Routes.settingsCache,
        Routes.settingsBackup,
        Routes.settingsNotifications,
      ]) {
        final matches = router.configuration.findMatch(Uri.parse(path));
        expect(matches.isError, isFalse);
        expect(matches.matches.map((match) => match.matchedLocation), [Routes.home, path]);
      }
    });

    test('recorder and onboarding remain full window siblings of home', () {
      for (final path in [Routes.record, Routes.onboarding]) {
        final matches = router.configuration.findMatch(Uri.parse(path));
        expect(matches.matches.map((match) => match.matchedLocation), [path]);
      }
    });

    test('journal selections replace the current detail without growing the stack', () {
      final first = router.configuration.findMatch(Uri.parse('/entry/a'));
      final second = router.configuration.findMatch(Uri.parse('/entry/b'));
      final reflection = router.configuration.findMatch(
        Uri.parse('/reflections?period=daily&week=2026-11-14'),
      );
      for (final selection in [first, second, reflection]) {
        expect(selection.matches.length, 2);
        expect(selection.matches.first.matchedLocation, Routes.home);
      }
      expect(second.pathParameters, {'id': 'b'});
      expect(reflection.uri.queryParameters['period'], 'daily');
    });

    test('menu pages push above a nested selection and keep its return location', () {
      final entry = router.configuration.findMatch(Uri.parse('/entry/a'));
      final cache = router.configuration.findMatch(Uri.parse(Routes.settingsCache));
      final pushed = entry.push(
        ImperativeRouteMatch(
          pageKey: const ValueKey('cache-push'),
          matches: cache,
          completer: Completer<Object?>(),
        ),
      );
      expect(pushed.matches.map((match) => match.matchedLocation), [
        Routes.home,
        '/entry/a',
        Routes.settingsCache,
      ]);
      expect(pushed.remove(pushed.matches.last).uri, entry.uri);
    });

    test('the named detail paths preserve parameters and queries', () {
      expect(router.namedLocation(Routes.entryName, pathParameters: {'id': 'a'}), '/entry/a');
      expect(router.namedLocation(Routes.settingsModelsName), Routes.settingsModels);
      expect(
        router.namedLocation(Routes.recordName, queryParameters: {Routes.recordEntryQuery: 'a'}),
        '/record?entry=a',
      );
    });
  });
  group('canOpenRecorder', () {
    test('a stack without the recorder may open it', () {
      expect(canOpenRecorder(stack: [Routes.home], onboardingDone: true), isTrue);
      expect(canOpenRecorder(stack: [Routes.home, '/entry/x'], onboardingDone: true), isTrue);
    });

    test('a recorder over a nested entry is already open', () {
      expect(
        canOpenRecorder(stack: [Routes.home, '/entry/a', Routes.record], onboardingDone: true),
        isFalse,
      );
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

    test('an unfinished user already at onboarding is not redirected', () {
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
      for (final path in [
        Routes.settingsCache,
        Routes.settingsModels,
        Routes.reflections,
        Routes.record,
      ]) {
        expect(resolveRedirect(onboardingDone: true, matchedLocation: path), isNull);
        expect(resolveRedirect(onboardingDone: false, matchedLocation: path), Routes.onboarding);
      }
    });
  });
}
