import 'package:opentranscribe/core/routes/routes.dart';

enum HomeDestination {
  home('act:home', Routes.homeName, Routes.home),
  models('act:models', Routes.settingsModelsName, Routes.settingsModels),
  reflections('act:reflections', Routes.reflectionsName, Routes.reflections),
  notifications(
    'act:notifications',
    Routes.settingsNotificationsName,
    Routes.settingsNotifications,
  ),
  cache('act:cache', Routes.settingsCacheName, Routes.settingsCache),
  backup('act:backup', Routes.settingsBackupName, Routes.settingsBackup),
  appearance('act:appearance', Routes.settingsAppearanceName, Routes.settingsAppearance);

  const HomeDestination(this.actionId, this.routeName, this.path);

  final String actionId;
  final String routeName;
  final String path;

  static HomeDestination? forAction(String id) {
    for (final destination in values) {
      if (destination.actionId == id) return destination;
    }
    return null;
  }

  bool selectedBy(Uri? selection) => this == home
      ? selection == null ||
            selection.path == Routes.home ||
            selection.path.startsWith(Routes.entry.replaceFirst(':id', ''))
      : selection?.path == path;
}

bool canChangeHomeSelection({
  required bool covered,
  required bool blocked,
  required Uri current,
  required Uri target,
}) => !covered && !blocked && current != target;
