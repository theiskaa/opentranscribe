import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:opentranscribe/core/app/deps.dart';
import 'package:opentranscribe/core/app/onboarding.dart';
import 'package:opentranscribe/core/routes/app_pages.dart';
import 'package:opentranscribe/core/routes/routes.dart';
import 'package:opentranscribe/core/routes/slide_page.dart';
import 'package:opentranscribe/view/layouts/entry/screens/entry_detail_screen.dart';
import 'package:opentranscribe/view/layouts/gallery/screens/gallery_screen.dart';
import 'package:opentranscribe/view/layouts/home/screens/home_screen.dart';
import 'package:opentranscribe/view/layouts/onboarding/screens/onboarding_screen.dart';
import 'package:opentranscribe/view/layouts/recorder/screens/recorder_screen.dart';
import 'package:opentranscribe/view/layouts/settings/screens/appearance_screen.dart';
import 'package:opentranscribe/view/layouts/settings/screens/models_screen.dart';

/// Owns the app's [GoRouter] instance.
///
/// Built once and held in [Deps]. Add new routes to [config] and their paths
/// to [Routes]. Home IS the app; everything else (settings, recorder, entry
/// detail) pushes over it on the one root navigator with a base transition.
/// There is no shell and no bottom navigation - settings and recording hang off
/// home's trailing bar actions.
class AppRouter {
  AppRouter();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  late final GoRouter config = GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: Routes.home,
    // Send a first-run user to onboarding until they finish it, and never back
    // into it once done. A synchronous storage read, so it is cheap on every
    // navigation. The splash (App.build) runs first; this fires as it lifts.
    redirect: (context, state) {
      final done = Onboarding.isDone(Deps.i.localService);
      final atOnboarding = state.matchedLocation == Routes.onboarding;
      if (!done && !atOnboarding) return Routes.onboarding;
      if (done && atOnboarding) return Routes.home;
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.home,
        name: Routes.homeName,
        // The base of the stack: it does not slide in, everything slides in
        // over it.
        pageBuilder: (context, state) =>
            NoTransitionPage(key: state.pageKey, child: const HomeScreen()),
      ),
      GoRoute(
        path: Routes.onboarding,
        name: Routes.onboardingName,
        // No transition: the splash cuts straight to it on a cold first launch.
        pageBuilder: (context, state) =>
            NoTransitionPage(key: state.pageKey, child: const OnboardingScreen()),
      ),
      GoRoute(
        path: Routes.entry,
        name: Routes.entryName,
        pageBuilder: (context, state) => SlidePage<void>(
          key: state.pageKey,
          child: EntryDetailScreen(entryId: state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: Routes.settingsModels,
        name: Routes.settingsModelsName,
        pageBuilder: (context, state) =>
            SlidePage<void>(key: state.pageKey, child: const ModelsScreen()),
      ),
      GoRoute(
        path: Routes.settingsAppearance,
        name: Routes.settingsAppearanceName,
        pageBuilder: (context, state) =>
            SlidePage<void>(key: state.pageKey, child: const AppearanceScreen()),
      ),
      GoRoute(
        path: Routes.record,
        name: Routes.recordName,
        pageBuilder: (context, state) =>
            SlideUpPage<void>(key: state.pageKey, child: const RecorderScreen()),
      ),
      if (kDebugMode)
        GoRoute(
          path: Routes.gallery,
          name: Routes.galleryName,
          // A fade, not a slide: the gallery mounts several platform views and
          // sliding them horizontally is what made the push read as laggy.
          pageBuilder: (context, state) =>
              FadePage<void>(key: state.pageKey, child: const GalleryScreen()),
        ),
    ],
  );
}
