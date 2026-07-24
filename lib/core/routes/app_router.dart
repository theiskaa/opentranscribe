import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:opentranscribe/core/routes/app_pages.dart';
import 'package:opentranscribe/core/routes/routes.dart';
import 'package:opentranscribe/view/layouts/entry/screens/entry_detail_screen.dart';
import 'package:opentranscribe/view/layouts/gallery/screens/gallery_screen.dart';
import 'package:opentranscribe/view/layouts/home/screens/home_screen.dart';
import 'package:opentranscribe/view/layouts/recorder/screens/recorder_screen.dart';
import 'package:opentranscribe/view/layouts/settings/screens/app_language_screen.dart';
import 'package:opentranscribe/view/layouts/settings/screens/appearance_screen.dart';
import 'package:opentranscribe/view/layouts/settings/screens/language_screen.dart';
import 'package:opentranscribe/view/layouts/settings/screens/models_screen.dart';
import 'package:opentranscribe/view/layouts/settings/screens/settings_screen.dart';

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
        path: Routes.settings,
        name: Routes.settingsName,
        // The base navigation transition (SlidePage): settings slides in from
        // the trailing edge and pops back the same way, and home's glass bar
        // group hides itself for the transition via the platform view's own
        // cover detection - no manual guard, no lag.
        pageBuilder: (context, state) =>
            SlidePage<void>(key: state.pageKey, child: const SettingsScreen()),
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
        path: Routes.settingsLanguage,
        name: Routes.settingsLanguageName,
        pageBuilder: (context, state) =>
            SlidePage<void>(key: state.pageKey, child: const LanguageScreen()),
      ),
      GoRoute(
        path: Routes.settingsAppLanguage,
        name: Routes.settingsAppLanguageName,
        pageBuilder: (context, state) =>
            SlidePage<void>(key: state.pageKey, child: const AppLanguageScreen()),
      ),
      GoRoute(
        path: Routes.settingsAppearance,
        name: Routes.settingsAppearanceName,
        pageBuilder: (context, state) =>
            SlidePage<void>(key: state.pageKey, child: const AppearanceScreen()),
      ),
      GoRoute(
        path: Routes.settingsModels,
        name: Routes.settingsModelsName,
        pageBuilder: (context, state) =>
            SlidePage<void>(key: state.pageKey, child: const ModelsScreen()),
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
