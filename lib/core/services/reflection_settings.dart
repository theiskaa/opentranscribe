import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/models/reflection.dart';
import 'package:opentranscribe/core/reflect/reflection_options.dart';
import 'package:opentranscribe/core/reflect/reflection_period.dart';

// The storage is private and named parameters cannot be, so an initializing
// formal does not apply.
// ignore_for_file: prefer_initializing_formals

/// Persists the reflection preferences per period (whether each of daily,
/// weekly, monthly runs, and its three style knobs) plus one piece of machinery
/// state: the per-period no-backfill [floorFor] the service records on first
/// run. Keyed `reflect.<period>.<knob>`. LocalService-backed like the other
/// settings holders. Reads are defensive: a corrupt or absent value falls back
/// to its default, never throws.
///
/// Defaults track the app's history: weekly is on, daily and monthly are off, so
/// nothing changes for an existing user until they opt a period in. Each
/// period's style defaults to the literary voice; length starts one-line for a
/// day and a paragraph for a month, matching how much each period has to say.
class ReflectionSettings {
  ReflectionSettings({required LocalService storage}) : _storage = storage;

  final LocalService _storage;

  String _key(ReflectionPeriod period, String knob) => 'reflect.${period.wire}.$knob';

  /// Whether [period] generates. Weekly is on by default; daily and monthly are
  /// off until the user turns them on.
  bool enabledFor(ReflectionPeriod period) => _read(
    _key(period, 'enabled'),
    (s) => s == null ? null : s != 'false',
    _enabledDefault(period),
  );

  /// Whether any period generates: the single gate the catch-up checks before
  /// doing any work.
  bool get anyEnabled => ReflectionPeriod.values.any(enabledFor);

  ReflectionVoice voiceFor(ReflectionPeriod period) =>
      _read(_key(period, 'voice'), ReflectionVoice.fromWire, ReflectionVoice.fallback);

  ReflectionLength lengthFor(ReflectionPeriod period) =>
      _read(_key(period, 'length'), ReflectionLength.fromWire, _lengthDefault(period));

  ReflectionSpecificity specificityFor(ReflectionPeriod period) => _read(
    _key(period, 'specificity'),
    ReflectionSpecificity.fromWire,
    ReflectionSpecificity.fallback,
  );

  ReflectionStyle styleFor(ReflectionPeriod period) => ReflectionStyle(
    voice: voiceFor(period),
    length: lengthFor(period),
    specificity: specificityFor(period),
  );

  /// [period]'s no-backfill floor: the period start of the day it first ran, or
  /// null before the service has recorded it. Periods that closed entirely
  /// before it are never reflected, so enabling one cannot churn old history
  /// through the model. Written once per period, by the service.
  DateTime? floorFor(ReflectionPeriod period) =>
      _read<DateTime?>(_key(period, 'floor'), (s) => s == null ? null : DateTime.tryParse(s), null);

  /// Whether a floor record exists for [period] at all, parseable or not.
  /// Corruption must not read as absence: the service would otherwise re-record
  /// the floor at the current period and orphan the journaled periods below it.
  bool floorRecordedFor(ReflectionPeriod period) => _storage.containsKey(_key(period, 'floor'));

  Future<void> setFloorFor(ReflectionPeriod period, DateTime start) =>
      _storage.write(_key(period, 'floor'), Reflection.keyFor(start));

  Future<void> setEnabledFor(ReflectionPeriod period, bool value) =>
      _storage.write(_key(period, 'enabled'), value ? 'true' : 'false');

  Future<void> setVoiceFor(ReflectionPeriod period, ReflectionVoice value) =>
      _storage.write(_key(period, 'voice'), value.wire);

  Future<void> setLengthFor(ReflectionPeriod period, ReflectionLength value) =>
      _storage.write(_key(period, 'length'), value.wire);

  Future<void> setSpecificityFor(ReflectionPeriod period, ReflectionSpecificity value) =>
      _storage.write(_key(period, 'specificity'), value.wire);

  static bool _enabledDefault(ReflectionPeriod period) => period == ReflectionPeriod.weekly;

  static ReflectionLength _lengthDefault(ReflectionPeriod period) => switch (period) {
    ReflectionPeriod.daily => ReflectionLength.oneLine,
    ReflectionPeriod.weekly => ReflectionLength.fallback,
    ReflectionPeriod.monthly => ReflectionLength.paragraph,
  };

  // The weekly-period surface, for the consumers not yet moved onto the
  // per-period API (the cubit, the notifier). They read and write weekly today;
  // later phases point them at the *For methods and these fall away.
  bool get enabled => enabledFor(ReflectionPeriod.weekly);
  ReflectionVoice get voice => voiceFor(ReflectionPeriod.weekly);
  ReflectionLength get length => lengthFor(ReflectionPeriod.weekly);
  ReflectionSpecificity get specificity => specificityFor(ReflectionPeriod.weekly);
  ReflectionStyle get style => styleFor(ReflectionPeriod.weekly);
  DateTime? get floor => floorFor(ReflectionPeriod.weekly);
  bool get floorRecorded => floorRecordedFor(ReflectionPeriod.weekly);
  Future<void> setFloor(DateTime week) => setFloorFor(ReflectionPeriod.weekly, week);
  Future<void> setEnabled(bool value) => setEnabledFor(ReflectionPeriod.weekly, value);
  Future<void> setVoice(ReflectionVoice value) => setVoiceFor(ReflectionPeriod.weekly, value);
  Future<void> setLength(ReflectionLength value) => setLengthFor(ReflectionPeriod.weekly, value);
  Future<void> setSpecificity(ReflectionSpecificity value) =>
      setSpecificityFor(ReflectionPeriod.weekly, value);

  T _read<T>(String key, T? Function(String?) fromWire, T fallback) {
    try {
      return fromWire(_storage.readString(key)) ?? fallback;
    } catch (_) {
      return fallback;
    }
  }
}
