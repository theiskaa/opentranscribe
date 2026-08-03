import 'package:opentranscribe/core/reflect/reflection_engine.dart';
import 'package:opentranscribe/core/reflect/reflection_exception.dart';
import 'package:opentranscribe/core/reflect/reflection_options.dart';
import 'package:opentranscribe/core/reflect/reflection_period.dart';

/// Deterministic reflection engine for tests and dev harnesses. On-device by
/// contract, like the real one. Configure its [availabilityResult], its
/// [output] (or set [silent] to return null), or set [failReflect] to exercise
/// the [ReflectionUnavailable] path. It records the last call's arguments so a
/// test can prove the week's material and style crossed the boundary intact.
class FakeReflectionEngine implements ReflectionEngine {
  FakeReflectionEngine({
    this.availabilityResult = const ReflectionAvailability.available(),
    this.output = 'a canned reflection',
    this.silent = false,
    this.failReflect = false,
  });

  /// Mutable so a test can flip availability or output between calls.
  ReflectionAvailability availabilityResult;
  String? output;
  bool silent;
  bool failReflect;

  /// Thrown as-is when set, for the unexpected-failure paths that must not be
  /// read as the transient [ReflectionUnavailable].
  Object? error;

  /// Holds [reflect] open until completed, so a test can exercise the
  /// single-flight guard with a call parked mid-generation.
  Future<void>? gate;

  List<ReflectionEntryInput>? lastEntries;
  ReflectionStyle? lastStyle;
  String? lastLocaleId;
  ReflectionPeriod? lastPeriod;
  int reflectCalls = 0;

  @override
  String get id => 'fake.reflection';

  @override
  bool get onDeviceOnly => true;

  @override
  Future<ReflectionAvailability> availability() async => availabilityResult;

  @override
  Future<String?> reflect({
    required ReflectionPeriod period,
    required List<ReflectionEntryInput> entries,
    required ReflectionStyle style,
    required String localeId,
  }) async {
    reflectCalls++;
    lastEntries = entries;
    lastStyle = style;
    lastLocaleId = localeId;
    lastPeriod = period;
    if (gate != null) await gate;
    if (failReflect) throw const ReflectionUnavailable('fake reflect failure');
    if (error != null) throw error!;
    return silent ? null : output;
  }
}
