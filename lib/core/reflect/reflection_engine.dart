import 'package:flutter/foundation.dart';

import 'package:opentranscribe/core/reflect/reflection_options.dart';

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
  const ReflectionAvailability(this.status, {this.detail});

  const ReflectionAvailability.available()
    : status = ReflectionAvailabilityStatus.available,
      detail = null;

  const ReflectionAvailability.unsupported()
    : status = ReflectionAvailabilityStatus.unsupported,
      detail = null;

  final ReflectionAvailabilityStatus status;
  final String? detail;

  bool get isAvailable => status == ReflectionAvailabilityStatus.available;

  @override
  bool operator ==(Object other) =>
      other is ReflectionAvailability && other.status == status && other.detail == detail;

  @override
  int get hashCode => Object.hash(status, detail);
}

/// One day's material from a week, as the engine sees it. Text only: no audio
/// ever crosses this boundary, the same rule the transcription engine holds.
/// [weekday] is 1..7 (Monday..Sunday, matching `DateTime.weekday`) so the model
/// can perceive the arc of the week without being handed dates.
@immutable
final class ReflectionEntryInput {
  const ReflectionEntryInput({required this.weekday, required this.text, this.title});

  final int weekday;
  final String text;
  final String? title;

  Map<String, dynamic> toWire() => {
    'weekday': weekday,
    'text': text,
    if (title != null) 'title': title,
  };

  @override
  bool operator ==(Object other) =>
      other is ReflectionEntryInput &&
      other.weekday == weekday &&
      other.text == text &&
      other.title == title;

  @override
  int get hashCode => Object.hash(weekday, text, title);
}

/// The one boundary the app talks to for weekly reflections. On-device only, by
/// the same hard rule as transcription: the app refuses any engine that answers
/// [onDeviceOnly] false, so a week's text can never quietly leave the phone.
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

  /// Reflects on a week from its [entries], in the requested [style] and
  /// [localeId].
  ///
  /// Returns the reflection text, or null for SILENCE. Silence is a valid,
  /// expected outcome: an empty week, or a week the observer had nothing to say
  /// about, or a guardrail refusal, all answer null. Silence is definitive and
  /// the caller persists it as such.
  ///
  /// THROWS [ReflectionUnavailable] only when the engine could not run at all
  /// (the model was not usable, a channel failure). That is transient, distinct
  /// from silence, so the caller leaves the week unreflected and retries later
  /// instead of storing a false quiet week.
  ///
  /// An implementation MUST instruct the model to observe and never to reply,
  /// advise, comfort, or address the user, and MUST permit empty output.
  Future<String?> reflect({
    required List<ReflectionEntryInput> entries,
    required ReflectionStyle style,
    required String localeId,
  });
}
