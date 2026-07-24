/// Route paths and names, kept in one place so navigation call sites and the
/// router agree on a single source of truth.
abstract final class Routes {
  static const home = '/';
  static const homeName = 'home';

  static const settings = '/settings';
  static const settingsName = 'settings';

  /// The transcription-language picker, pushed over settings.
  static const settingsLanguage = '/settings/language';
  static const settingsLanguageName = 'settingsLanguage';

  /// The app-language (UI locale) picker, pushed over settings.
  static const settingsAppLanguage = '/settings/app-language';
  static const settingsAppLanguageName = 'settingsAppLanguage';

  /// The appearance (theme) screen, pushed over settings.
  static const settingsAppearance = '/settings/appearance';
  static const settingsAppearanceName = 'settingsAppearance';

  /// The transcription models screen, pushed over settings.
  static const settingsModels = '/settings/models';
  static const settingsModelsName = 'settingsModels';

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
