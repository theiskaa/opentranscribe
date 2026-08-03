import 'package:flutter/foundation.dart';

import 'package:opentranscribe/core/reflect/reflection_options.dart';
import 'package:opentranscribe/core/reflect/reflection_period.dart';

/// Why reflections can or cannot run on this device right now. Mirrors the
/// system model's own states so the gate and any status surface name the same
/// condition the same way. Only [available] runs; [notEnabled] and
/// [modelNotReady] are eligible hardware the OS has not made ready yet (surfaced
/// as help); [deviceNotEligible] and [unsupported] mean the feature does not
/// exist here, and stay fully invisible.
enum ReflectionAvailabilityStatus {
  available,
  notEnabled,
  modelNotReady,
  deviceNotEligible,
  unsupported,
}

@immutable
final class ReflectionAvailability {
  const ReflectionAvailability(this.status);

  const ReflectionAvailability.available() : status = ReflectionAvailabilityStatus.available;

  const ReflectionAvailability.unsupported() : status = ReflectionAvailabilityStatus.unsupported;

  final ReflectionAvailabilityStatus status;

  bool get isAvailable => status == ReflectionAvailabilityStatus.available;

  @override
  bool operator ==(Object other) => other is ReflectionAvailability && other.status == status;

  @override
  int get hashCode => status.hashCode;
}

/// One entry's material within a reflection's period, as the engine sees it.
/// Text only: no audio ever crosses this boundary, the same rule the
/// transcription engine holds. [date] is the civil date it was recorded on, so
/// the engine can render whatever day label the period calls for (a weekday
/// within a week, a day-of-month within a month) and perceive the period's arc.
@immutable
final class ReflectionEntryInput {
  ReflectionEntryInput({required DateTime date, required this.text, this.title})
    : date = DateTime(date.year, date.month, date.day);

  final DateTime date;
  final String text;
  final String? title;

  Map<String, dynamic> toWire() => {
    'date': _isoDate(date),
    'text': text,
    if (title != null) 'title': title,
  };

  @override
  bool operator ==(Object other) =>
      other is ReflectionEntryInput &&
      other.date == date &&
      other.text == text &&
      other.title == title;

  @override
  int get hashCode => Object.hash(date, text, title);
}

String _isoDate(DateTime d) {
  final month = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year.toString().padLeft(4, '0')}-$month-$day';
}

/// The one boundary the app talks to for reflections. On-device only, by the
/// same hard rule as transcription: the app refuses any engine that answers
/// [onDeviceOnly] false, so a reflection's text can never quietly leave the phone.
///
/// An engine that answers [ReflectionAvailability.isAvailable] false must never
/// have [reflect] called on it; the feature is simply absent then.
abstract interface class ReflectionEngine {
  String get id;

  /// Whether this engine runs entirely on-device. The app refuses any engine
  /// that answers false. There is no cloud fallback for reflections, ever.
  bool get onDeviceOnly;

  /// Preflight probe of whether reflections can run here. Never throws: an
  /// engine that cannot answer reports [ReflectionAvailabilityStatus.unsupported]
  /// rather than surfacing an error, keeping the feature invisible.
  Future<ReflectionAvailability> availability();

  /// Reflects on one [period] from its [entries], in the requested [style] and
  /// [localeId]. The [period] tells the implementation how to frame the read (a
  /// day, a week, a month) and what day label each entry carries.
  ///
  /// Returns the reflection text, or null for SILENCE. Silence is a valid,
  /// expected outcome: an empty period, or one the observer had nothing to say
  /// about, or a guardrail refusal, all answer null. Silence is definitive and
  /// the caller persists it as such.
  ///
  /// THROWS [ReflectionUnavailable] only when the engine could not run at all
  /// (the model was not usable, a channel failure). That is transient, distinct
  /// from silence, so the caller leaves the period unreflected and retries later
  /// instead of storing a false quiet period.
  ///
  /// An implementation MUST instruct the model to observe and never to reply,
  /// advise, comfort, or address the user, and MUST permit empty output.
  Future<String?> reflect({
    required ReflectionPeriod period,
    required List<ReflectionEntryInput> entries,
    required ReflectionStyle style,
    required String localeId,
  });
}
