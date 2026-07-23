/// Route paths and names, kept in one place so navigation call sites and the
/// router agree on a single source of truth.
abstract final class Routes {
  static const entries = '/';
  static const entriesName = 'entries';

  static const settings = '/settings';
  static const settingsName = 'settings';

  /// Entry detail. Relative to [entries]; navigate by name with an `id` param.
  static const entry = 'entry/:id';
  static const entryName = 'entry';
}
