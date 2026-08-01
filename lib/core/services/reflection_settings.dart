import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/models/reflection.dart';
import 'package:opentranscribe/core/reflect/reflection_options.dart';

// The storage is private and named parameters cannot be, so an initializing
// formal does not apply.
// ignore_for_file: prefer_initializing_formals

/// Persists the weekly-reflection preferences (whether reflections run, the
/// three style knobs) plus one piece of machinery state: the no-backfill
/// [floor] the service records on first run. LocalService-backed like the
/// other settings holders. Reads are defensive: a corrupt or absent value
/// falls back to its default (reflections on, the literary-tuned style, no
/// floor yet), never throws. The defaults track [ReflectionVoice.literary];
/// changing any knob affects future weeks only.
class ReflectionSettings {
  ReflectionSettings({required LocalService storage}) : _storage = storage;

  final LocalService _storage;

  static const _enabledKey = 'reflect.enabled';
  static const _voiceKey = 'reflect.voice';
  static const _lengthKey = 'reflect.length';
  static const _specificityKey = 'reflect.specificity';
  static const _floorKey = 'reflect.floor';

  /// On by default on capable devices; where the on-device model is unavailable
  /// nothing generates anyway, so a stored true costs nothing there.
  bool get enabled => _read(_enabledKey, (s) => s == null ? null : s != 'false', true);

  ReflectionVoice get voice => _read(_voiceKey, ReflectionVoice.fromWire, ReflectionVoice.fallback);

  ReflectionLength get length =>
      _read(_lengthKey, ReflectionLength.fromWire, ReflectionLength.fallback);

  ReflectionSpecificity get specificity =>
      _read(_specificityKey, ReflectionSpecificity.fromWire, ReflectionSpecificity.fallback);

  ReflectionStyle get style =>
      ReflectionStyle(voice: voice, length: length, specificity: specificity);

  /// The no-backfill floor: the week start of the day the feature first ran,
  /// or null before the service has recorded it. Weeks that closed entirely
  /// before it are never reflected, so an upgrade cannot churn pre-feature
  /// history through the model. Written once, by the service.
  DateTime? get floor =>
      _read<DateTime?>(_floorKey, (s) => s == null ? null : DateTime.tryParse(s), null);

  /// Whether a floor record exists at all, parseable or not. Corruption must
  /// not read as absence: the service would otherwise re-record the floor at
  /// the current week and permanently orphan the journaled weeks below the
  /// true one.
  bool get floorRecorded => _storage.containsKey(_floorKey);

  Future<void> setFloor(DateTime week) => _storage.write(_floorKey, Reflection.keyFor(week));

  Future<void> setEnabled(bool value) => _storage.write(_enabledKey, value ? 'true' : 'false');

  Future<void> setVoice(ReflectionVoice value) => _storage.write(_voiceKey, value.wire);

  Future<void> setLength(ReflectionLength value) => _storage.write(_lengthKey, value.wire);

  Future<void> setSpecificity(ReflectionSpecificity value) =>
      _storage.write(_specificityKey, value.wire);

  T _read<T>(String key, T? Function(String?) fromWire, T fallback) {
    try {
      return fromWire(_storage.readString(key)) ?? fallback;
    } catch (_) {
      return fallback;
    }
  }
}
