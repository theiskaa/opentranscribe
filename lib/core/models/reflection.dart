import 'package:flutter/foundation.dart';

import 'package:opentranscribe/core/reflect/reflection_options.dart';
import 'package:opentranscribe/core/utils/week.dart';

/// One week's reflection, stored like any other local entry data. Keyed by
/// [weekStart], the civil date of the week's first day (aligned to the app's
/// locale week model). A week has exactly one reflection.
///
/// [text] null is SILENCE: the observer ran and had nothing to say, the valid
/// default outcome, rendered as "a quiet week". It is a stored result, not an
/// absence: no stored reflection at all means the week is not yet reflected. So
/// a silent week is never re-run, while an unreflected one still is.
///
/// A reflection is an immutable snapshot of the week as it read then; later
/// edits to that week's entries do not change it. A user may regenerate one
/// explicitly, which replaces it.
@immutable
final class Reflection {
  /// [weekStart] is a civil date, not an instant: it is normalized to its
  /// year/month/day and carries no timezone, because a week boundary is a
  /// calendar day, not a moment. [generatedAt] IS an instant, stored UTC.
  Reflection({
    required DateTime weekStart,
    required DateTime generatedAt,
    this.text,
    this.voice,
  }) : weekStart = dateOnly(weekStart),
       generatedAt = generatedAt.toUtc();

  final DateTime weekStart;
  final DateTime generatedAt;

  /// The reflection text, or null for silence (a quiet week).
  final String? text;

  /// The voice it was written in, kept for display and as context for a
  /// regenerate. Null on records from before this field.
  final ReflectionVoice? voice;

  bool get isSilent => text == null;

  /// yyyy-MM-dd, the stable storage key for this week's reflection. The one
  /// place the key format lives, so save and read can never drift apart.
  static String keyFor(DateTime weekStart) {
    final d = dateOnly(weekStart);
    final month = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year.toString().padLeft(4, '0')}-$month-$day';
  }

  String get weekKey => keyFor(weekStart);

  Map<String, dynamic> toJson() => {
    'weekStart': weekKey,
    'generatedAt': generatedAt.toIso8601String(),
    if (text != null) 'text': text,
    if (voice != null) 'voice': voice!.wire,
  };

  factory Reflection.fromJson(Map<String, dynamic> json) => Reflection(
    weekStart: DateTime.parse(json['weekStart'] as String),
    generatedAt: DateTime.parse(json['generatedAt'] as String),
    // Absent on a silent week (nothing to say) and present otherwise.
    text: json['text'] as String?,
    voice: ReflectionVoice.fromWire(json['voice'] as String?),
  );

  @override
  bool operator ==(Object other) =>
      other is Reflection &&
      other.weekStart == weekStart &&
      other.generatedAt == generatedAt &&
      other.text == text &&
      other.voice == voice;

  @override
  int get hashCode => Object.hash(weekStart, generatedAt, text, voice);
}
