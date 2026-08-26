/// Route paths and names, kept in one place so navigation call sites and the
/// router agree on a single source of truth.
///
/// There is no single settings screen: the home menu ([HomeMenu]) is the
/// settings surface, and each `settings*` route below is pushed straight
/// from it.
abstract final class Routes {
  static const home = '/';
  static const homeName = 'home';

  /// First-launch onboarding (intro, permissions, model download). Gated by the
  /// router's redirect on [Onboarding.isDone]; shown once, then never again.
  static const onboarding = '/onboarding';
  static const onboardingName = 'onboarding';

  /// The models screen (per-language on-device speech models). Pushed over
  /// home from the menu.
  static const settingsModels = '/settings/models';
  static const settingsModelsName = 'settingsModels';

  /// The appearance (theme) screen, pushed over home from the menu.
  static const settingsAppearance = '/settings/appearance';
  static const settingsAppearanceName = 'settingsAppearance';

  /// The cache screen (audio storage usage, keep-audio, bulk clear).
  static const settingsCache = '/settings/cache';
  static const settingsCacheName = 'settingsCache';

  /// The backup screen (export, archive, import).
  static const settingsBackup = '/settings/backup';
  static const settingsBackupName = 'settingsBackup';

  /// The notifications screen (local, on-device nudges: a master switch, a
  /// toggle per reflection period, and one shared time). Pushed over home
  /// from the menu.
  static const settingsNotifications = '/settings/notifications';
  static const settingsNotificationsName = 'settingsNotifications';

  /// The support screen (the supporter purchase, restore, and manage
  /// surface). Pushed over home from the menu, and from the gate sheet a
  /// locked export answers with.
  static const settingsSupport = '/settings/support';
  static const settingsSupportName = 'settingsSupport';

  /// The ONE reflections surface: past weeks one page at a time, with the one
  /// menu acting on the viewed week. Reached plain from the home menu (lands
  /// on the newest closed week), or with a `week` query parameter
  /// (yyyy-MM-dd, [Reflection.keyFor]) to land on a specific week - how a
  /// home card opens its reflection. An unknown week falls back to the
  /// newest.
  static const reflections = '/reflections';
  static const reflectionsName = 'reflections';

  /// Entry detail. Navigate by name with an `id` param; pushes over the shell.
  static const entry = '/entry/:id';
  static const entryName = 'entry';

  /// The recorder, a full-screen sheet over the shell.
  static const record = '/record';
  static const recordName = 'record';
}
