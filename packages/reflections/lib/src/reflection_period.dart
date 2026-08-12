import 'package:reflections/src/reflection_options.dart';

/// The granularity a reflection covers. Each period is an independent stream: a
/// user may enable any combination, and a day, its week, and its month are
/// three distinct reflections with distinct records, never one folded into
/// another.
///
/// [wire] is the cross-boundary spelling, the storage key segment, settings key
/// fragment, and native prompt tag, like the option enums. It is a stable
/// contract: never repurpose a value.
enum ReflectionPeriod {
  daily('daily'),
  weekly('weekly'),
  monthly('monthly');

  const ReflectionPeriod(this.wire);

  final String wire;

  /// The period a record with no stored period is read as, matching the app's
  /// original weekly-only behavior.
  static const fallback = ReflectionPeriod.weekly;

  /// The period for a stored [wire] value, or null when unrecognized (a record
  /// from a future build); callers fall back rather than throw.
  static ReflectionPeriod? fromWire(String? wire) => enumFromWire(values, (v) => v.wire, wire);
}
