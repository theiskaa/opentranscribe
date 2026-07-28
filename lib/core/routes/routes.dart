/// Route paths and names, kept in one place so navigation call sites and the
/// router agree on a single source of truth.
abstract final class Routes {
  static const home = '/';
  static const homeName = 'home';

  /// First-launch onboarding (intro, permissions, model download). Gated by the
  /// router's redirect on [Onboarding.isDone]; shown once, then never again.
  static const onboarding = '/onboarding';
  static const onboardingName = 'onboarding';

  /// The models screen (per-language on-device models). There is no settings
  /// screen: the home menu ([HomeMenu]) is the settings surface, and Models is
  /// the one setting deep enough to earn its own screen. Pushed over home.
  static const settingsModels = '/settings/models';
  static const settingsModelsName = 'settingsModels';

  /// The appearance (theme) screen, pushed over home from the menu.
  static const settingsAppearance = '/settings/appearance';
  static const settingsAppearanceName = 'settingsAppearance';

  /// Entry detail. Navigate by name with an `id` param; pushes over the shell.
  static const entry = '/entry/:id';
  static const entryName = 'entry';

  /// The recorder, a full-screen sheet over the shell.
  static const record = '/record';
  static const recordName = 'record';

  /// The widget gallery, registered in debug builds only.
  static const gallery = '/gallery';
  static const galleryName = 'gallery';
}
