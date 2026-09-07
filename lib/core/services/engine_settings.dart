import 'package:opentranscribe/core/app/engine_registry.dart';
import 'package:opentranscribe/core/app/local_service.dart';

/// Persists the engine choice and each engine's model choice. An unset engine
/// means auto: the first available registry
/// entry, so a device that cannot run the preferred engine starts on one that
/// works without the user touching anything.
class EngineSettings {
  EngineSettings({required this._storage});

  final LocalService _storage;

  static const _key = 'transcribe.engineId';

  /// The stored engine id, or null when the user never chose (auto). Falls
  /// back to null when the stored value cannot be decrypted (key change,
  /// corruption), which resolves to auto rather than a dead choice.
  String? get engineId {
    try {
      return _storage.readString(_key);
    } catch (_) {
      return null;
    }
  }

  /// Persists the choice so it survives relaunches. Throws when persisting
  /// fails; the caller reverts the in-session switch and surfaces it.
  Future<void> setEngineId(String id) => _storage.write(_key, id);

  /// The stored model choice for [engineId], null when the user never chose
  /// (the engine's own default) or the value cannot be read.
  String? modelIdFor(String engineId) {
    try {
      return _storage.readString(_modelKey(engineId));
    } catch (_) {
      return null;
    }
  }

  /// Persists a model choice per engine, so switching engines never forgets
  /// what each one ran. Throws when persisting fails.
  Future<void> setModelId(String engineId, String modelId) =>
      _storage.write(_modelKey(engineId), modelId);

  static String _modelKey(String engineId) => 'transcribe.model.$engineId';

  /// Whether the user turned [engineId]'s acceleration on; false when never
  /// chosen or unreadable.
  bool acceleratedFor(String engineId) {
    try {
      return _storage.readString(_accelerationKey(engineId)) == 'on';
    } catch (_) {
      return false;
    }
  }

  /// Persists the acceleration choice per engine. Throws when persisting fails.
  Future<void> setAccelerated(String engineId, bool on) =>
      _storage.write(_accelerationKey(engineId), on ? 'on' : 'off');

  static String _accelerationKey(String engineId) => 'transcribe.acceleration.$engineId';

  /// The entry the app should run: the stored choice when that engine exists
  /// and is available, else the first available entry, else the first entry
  /// (an all-unavailable registry still needs a defined answer; every surface
  /// then reports that engine's own unavailability honestly). The registry
  /// must be non-empty.
  EngineEntry resolveActive(List<EngineEntry> registry) {
    final stored = engineId;
    for (final entry in registry) {
      if (entry.available && entry.descriptor.engineId == stored) return entry;
    }
    for (final entry in registry) {
      if (entry.available) return entry;
    }
    return registry.first;
  }
}
