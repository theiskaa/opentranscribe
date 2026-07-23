import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:opentranscribe/core/routes/routes.dart';
import 'package:opentranscribe/view/layouts/entries/screens/entries_screen.dart';
import 'package:opentranscribe/view/layouts/entries/screens/entry_detail_screen.dart';
import 'package:opentranscribe/view/layouts/settings/screens/settings_screen.dart';

/// Owns the app's [GoRouter] instance.
///
/// Built once and held in [Deps]. Add new routes to [config] and their paths
/// to [Routes].
class AppRouter {
  AppRouter();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  late final GoRouter config = GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: Routes.entries,
    routes: [
      GoRoute(
        path: Routes.entries,
        name: Routes.entriesName,
        builder: (context, state) => const EntriesScreen(),
        routes: [
          GoRoute(
            path: 'settings',
            name: Routes.settingsName,
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: Routes.entry,
            name: Routes.entryName,
            builder: (context, state) => EntryDetailScreen(entryId: state.pathParameters['id']!),
          ),
        ],
      ),
    ],
  );
}
