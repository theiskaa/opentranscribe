import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:opentranscribe/core/app/deps.dart';
import 'package:opentranscribe/core/app/onboarding.dart';
import 'package:opentranscribe/core/routes/app_pages.dart';
import 'package:opentranscribe/core/routes/routes.dart';
import 'package:opentranscribe/core/routes/pane_page.dart';
import 'package:opentranscribe/core/routes/pane_observer.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/view/layouts/entry/screens/entry_detail_screen.dart';
import 'package:opentranscribe/view/layouts/home/screens/home_screen.dart';
import 'package:opentranscribe/view/layouts/onboarding/screens/onboarding_screen.dart';
import 'package:opentranscribe/view/layouts/recorder/screens/recorder_screen.dart';
import 'package:opentranscribe/view/layouts/reflections/screens/reflections_screen.dart';
import 'package:opentranscribe/view/layouts/settings/screens/appearance_screen.dart';
import 'package:opentranscribe/view/layouts/settings/screens/backup_screen.dart';
import 'package:opentranscribe/view/layouts/settings/screens/cache_screen.dart';
import 'package:opentranscribe/view/layouts/settings/screens/models_screen.dart';
import 'package:opentranscribe/view/layouts/settings/screens/notifications_screen.dart';
import 'package:opentranscribe/view/widgets/pane_frame.dart';
import 'package:opentranscribe/view/widgets/duo_detail_swap.dart';

/// One root navigator. Details are children of home; recorder and onboarding
/// cover the whole window.
class AppRouter {
  AppRouter({bool Function()? onboardingDone})
    : _onboardingDone = onboardingDone ?? (() => Onboarding.isDone(Deps.i.localService));

  final bool Function() _onboardingDone;

  final PaneObserver paneObserver = PaneObserver();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Whether an action from a system surface may raise the recorder right now,
  /// resolved against the live stack. See [canOpenRecorder] for the rules.
  bool get recorderCanOpen => canOpenRecorder(
    stack: config.routerDelegate.currentConfiguration.matches
        .map((match) => match.matchedLocation)
        .toList(),
    onboardingDone: _onboardingDone(),
  );

  late final GoRouter config = GoRouter(
    navigatorKey: navigatorKey,
    observers: [paneObserver],
    initialLocation: Routes.home,
    // A synchronous storage read, so it is cheap on every navigation.
    redirect: (context, state) =>
        resolveRedirect(onboardingDone: _onboardingDone(), matchedLocation: state.matchedLocation),
    // The app has no deep-link surface, so an unroutable location is never
    // something the user asked for: iOS handed it to us. Home instead, quietly.
    onException: (context, state, router) => router.goNamed(Routes.homeName),
    routes: [
      GoRoute(
        path: Routes.home,
        name: Routes.homeName,
        // The base of the stack: everything slides in over it. On a plain
        // launch the initial route does not animate; the arrival fade only
        // plays on the swap out of onboarding.
        pageBuilder: (context, state) => ArrivalPage<void>(
          motion: context.motionNow,
          key: state.pageKey,
          child: const HomeScreen(),
        ),
        routes: [
          GoRoute(
            path: Routes.reflections.substring(1),
            name: Routes.reflectionsName,
            pageBuilder: (context, state) => PanePage<void>(
              key: state.pageKey,
              name: state.name,
              child: ReflectionsScreen(
                key: ValueKey(state.uri),
                initialPeriod: state.uri.queryParameters['period'],
                initialStartKey: state.uri.queryParameters['week'],
              ),
            ),
          ),
          GoRoute(
            path: Routes.entry.substring(1),
            name: Routes.entryName,
            pageBuilder: (context, state) => PanePage<void>(
              key: state.pageKey,
              name: state.name,
              fromProvisional: PaneLayoutScope.of(
                context,
              ).promotesProvisional(state.pathParameters['id']!),
              child: DuoDetailSwap(
                entryId: state.pathParameters['id']!,
                location: state.uri,
                child: RoutedEntryDetail(
                  entryId: state.pathParameters['id']!,
                  routeKey: state.pageKey,
                ),
              ),
            ),
          ),
          GoRoute(
            path: Routes.settingsModels.substring(1),
            name: Routes.settingsModelsName,
            pageBuilder: (context, state) =>
                PanePage<void>(key: state.pageKey, child: const ModelsScreen()),
          ),
          GoRoute(
            path: Routes.settingsAppearance.substring(1),
            name: Routes.settingsAppearanceName,
            pageBuilder: (context, state) =>
                PanePage<void>(key: state.pageKey, child: const AppearanceScreen()),
          ),
          GoRoute(
            path: Routes.settingsCache.substring(1),
            name: Routes.settingsCacheName,
            pageBuilder: (context, state) =>
                PanePage<void>(key: state.pageKey, child: const CacheScreen()),
          ),
          GoRoute(
            path: Routes.settingsBackup.substring(1),
            name: Routes.settingsBackupName,
            pageBuilder: (context, state) =>
                PanePage<void>(key: state.pageKey, child: const BackupScreen()),
          ),
          GoRoute(
            path: Routes.settingsNotifications.substring(1),
            name: Routes.settingsNotificationsName,
            pageBuilder: (context, state) =>
                PanePage<void>(key: state.pageKey, child: const NotificationsScreen()),
          ),
        ],
      ),
      GoRoute(
        path: Routes.onboarding,
        name: Routes.onboardingName,
        // No transition: the launch splash collapses straight onto it on a
        // cold launch.
        pageBuilder: (context, state) =>
            NoTransitionPage(key: state.pageKey, child: const OnboardingScreen()),
      ),
      GoRoute(
        path: Routes.record,
        name: Routes.recordName,
        pageBuilder: (context, state) => SlideUpPage<void>(
          motion: context.motionNow,
          key: state.pageKey,
          child: RecorderScreen(
            continueEntryId: state.uri.queryParameters[Routes.recordEntryQuery],
          ),
        ),
      ),
    ],
  );
}

/// Whether the recorder may be pushed over [stack], the matched location of
/// every page currently on the router, outermost first.
///
/// An empty stack means the router has no navigator yet (the first frame has
/// not mounted it): a push there replays against nothing when the router
/// mounts, which strands the recorder as the only page with nothing to pop.
///
/// An unfinished onboarding refuses too, because an imperative push runs through
/// [resolveRedirect] and would land a second onboarding page over the first.
///
/// The recorder anywhere in the stack, not merely on top, is already open: a
/// second sheet re-prepares the take and takes the running clock and text with
/// it.
bool canOpenRecorder({required List<String> stack, required bool onboardingDone}) {
  if (!onboardingDone) return false;
  if (stack.isEmpty) return false;
  return !stack.any((location) => Uri.parse(location).path == Routes.record);
}

/// First-run users land in onboarding; a finished user who reaches it goes
/// home.
String? resolveRedirect({required bool onboardingDone, required String matchedLocation}) {
  final atOnboarding = matchedLocation == Routes.onboarding;
  if (!onboardingDone && !atOnboarding) return Routes.onboarding;
  if (onboardingDone && atOnboarding) return Routes.home;
  return null;
}
