import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/models/reflection.dart';
import 'package:reflections/reflections.dart';

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
/// The week and the month write out of the box, the day does not
/// ([defaultEnabled]). Each period's style defaults to the literary voice;
/// length starts one-line for a day and a paragraph for a month, matching how
/// much each period has to say.
class ReflectionSettings {
  ReflectionSettings({required LocalService storage}) : _storage = storage;

  final LocalService _storage;

  String _key(ReflectionPeriod period, String knob) => 'reflect.${period.wire}.$knob';

  /// Whether [period] generates. The user turns on or off what they want;
  /// see [defaultEnabled] for where each starts.
  bool enabledFor(ReflectionPeriod period) => _read(
    _key(period, 'enabled'),
    (s) => s == null ? null : s != 'false',
    defaultEnabled(period),
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

  /// The out-of-the-box set: the week and the month write from the start, the
  /// day does not. A day is small enough that most of them read as a line
  /// about nothing, and a daily pass over the whole journal is the costly one
  /// to run unasked. The ONE statement of the default, which the disabled
  /// page's turn-on ([ReflectionsCubit.enableDefaults]) restores.
  static bool defaultEnabled(ReflectionPeriod period) => period != ReflectionPeriod.daily;

  static ReflectionLength _lengthDefault(ReflectionPeriod period) => switch (period) {
    ReflectionPeriod.daily => ReflectionLength.oneLine,
    ReflectionPeriod.weekly => ReflectionLength.fallback,
    ReflectionPeriod.monthly => ReflectionLength.paragraph,
  };

  T _read<T>(String key, T? Function(String?) fromWire, T fallback) {
    try {
      return fromWire(_storage.readString(key)) ?? fallback;
    } catch (_) {
      return fallback;
    }
  }
}
