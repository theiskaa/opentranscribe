import 'package:flutter/foundation.dart';

import 'package:opentranscribe/core/utils/week.dart';
import 'package:reflections/reflections.dart';

/// One period's reflection, stored like any other local entry data. Keyed by
/// [period] plus [periodStart], the civil date of the period's first day (its day,
/// its locale week's first day, or the first of its month). A given period has
/// exactly one reflection per start, and the same start date under two periods
/// is two distinct records.
///
/// [text] null is SILENCE: the observer ran and had nothing to say, the valid
/// default outcome, rendered as "a quiet week". It is a stored result, not an
/// absence: no stored reflection at all means the period is not yet reflected.
/// So a silent period is never re-run, while an unreflected one still is.
///
/// A reflection is an immutable snapshot of the period as it read then; later
/// edits to that period's entries do not change it. A user may regenerate one
/// explicitly, which replaces it.
@immutable
final class Reflection {
  /// [periodStart] is a civil date, not an instant: it is normalized to its
  /// year/month/day and carries no timezone, because a period boundary is a
  /// calendar day, not a moment. [generatedAt] IS an instant, stored UTC.
  Reflection({
    required DateTime periodStart,
    required DateTime generatedAt,
    this.period = ReflectionPeriod.weekly,
    this.text,
    this.voice,
  }) : periodStart = dateOnly(periodStart),
       generatedAt = generatedAt.toUtc();

  final ReflectionPeriod period;
  final DateTime periodStart;
  final DateTime generatedAt;

  /// The reflection text, or null for silence (a quiet week).
  final String? text;

  /// The voice it was written in, kept for display and as context for a
  /// regenerate. Null on records from before this field.
  final ReflectionVoice? voice;

  bool get isSilent => text == null;

  /// yyyy-MM-dd, the stable date segment of a reflection's storage key, and the
  /// wire format for any stored period start (the settings floor writes through
  /// it and reads back with an ISO-8601 parse). The one place the format
  /// lives, so writers and readers can never drift apart.
  static String keyFor(DateTime periodStart) {
    final d = dateOnly(periodStart);
    final month = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year.toString().padLeft(4, '0')}-$month-$day';
  }

  String get periodKey => keyFor(periodStart);

  Map<String, dynamic> toJson() => {
    'period': period.wire,
    'periodStart': periodKey,
    'generatedAt': generatedAt.toIso8601String(),
    if (text != null) 'text': text,
    if (voice != null) 'voice': voice!.wire,
  };

  factory Reflection.fromJson(Map<String, dynamic> json) => Reflection(
    period: ReflectionPeriod.fromWire(json['period'] as String?) ?? ReflectionPeriod.fallback,
    periodStart: DateTime.parse(json['periodStart'] as String),
    generatedAt: DateTime.parse(json['generatedAt'] as String),
    // Absent on a silent period (nothing to say) and present otherwise.
    text: json['text'] as String?,
    voice: ReflectionVoice.fromWire(json['voice'] as String?),
  );

  @override
  bool operator ==(Object other) =>
      other is Reflection &&
      other.period == period &&
      other.periodStart == periodStart &&
      other.generatedAt == generatedAt &&
      other.text == text &&
      other.voice == voice;

  @override
  int get hashCode => Object.hash(period, periodStart, generatedAt, text, voice);
}
