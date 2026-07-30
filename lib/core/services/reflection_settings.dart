import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/reflect/reflection_options.dart';

// The storage is private and named parameters cannot be, so an initializing
// formal does not apply.
// ignore_for_file: prefer_initializing_formals

/// Persists the weekly-reflection preferences: whether reflections run, and the
/// three style knobs. LocalService-backed like the other settings holders.
/// Reads are defensive: a corrupt or absent value falls back to the default
/// (reflections on, the literary-tuned style), never throws. The defaults track
/// [ReflectionVoice.literary]; changing any knob affects future weeks only.
class ReflectionSettings {
  ReflectionSettings({required LocalService storage}) : _storage = storage;

  final LocalService _storage;

  static const _enabledKey = 'reflect.enabled';
  static const _voiceKey = 'reflect.voice';
  static const _lengthKey = 'reflect.length';
  static const _specificityKey = 'reflect.specificity';

  /// On by default on capable devices; where Apple Intelligence is unavailable
  /// nothing generates anyway, so a stored true costs nothing there.
  bool get enabled => _read(_enabledKey, (s) => s == null ? null : s != 'false', true);

  ReflectionVoice get voice => _read(_voiceKey, ReflectionVoice.fromWire, ReflectionVoice.fallback);

  ReflectionLength get length =>
      _read(_lengthKey, ReflectionLength.fromWire, ReflectionLength.fallback);

  ReflectionSpecificity get specificity =>
      _read(_specificityKey, ReflectionSpecificity.fromWire, ReflectionSpecificity.fallback);

  ReflectionStyle get style =>
      ReflectionStyle(voice: voice, length: length, specificity: specificity);

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
