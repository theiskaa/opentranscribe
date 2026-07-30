import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/models/reflection.dart';
import 'package:opentranscribe/core/reflect/reflection_options.dart';

void main() {
  test('round-trips a written reflection through JSON', () {
    final r = Reflection(
      weekStart: DateTime(2026, 7, 20),
      generatedAt: DateTime.utc(2026, 7, 26, 9),
      text: 'Work threaded through most of the week.',
      voice: ReflectionVoice.literary,
    );

    expect(Reflection.fromJson(r.toJson()), r);
  });

  test('round-trips a silent reflection: null text survives as silence', () {
    final r = Reflection(
      weekStart: DateTime(2026, 7, 20),
      generatedAt: DateTime.utc(2026, 7, 26, 9),
    );

    final back = Reflection.fromJson(r.toJson());
    expect(back, r);
    expect(back.isSilent, isTrue);
    // A silent week stores no text key at all, so it reads back as null, not ''.
    expect(r.toJson().containsKey('text'), isFalse);
  });

  test('weekStart is a civil date: time and timezone are dropped', () {
    final r = Reflection(
      // A wall-clock instant on the boundary day, in some local zone.
      weekStart: DateTime(2026, 7, 20, 23, 59),
      generatedAt: DateTime.utc(2026, 7, 26),
    );

    expect(r.weekStart, DateTime(2026, 7, 20));
    expect(r.weekKey, '2026-07-20');
  });

  test('an unrecognized stored voice reads back as null, not a throw', () {
    final json = {
      'weekStart': '2026-07-20',
      'generatedAt': DateTime.utc(2026, 7, 26).toIso8601String(),
      'text': 'x',
      'voice': 'from_a_future_build',
    };

    expect(Reflection.fromJson(json).voice, isNull);
  });

  test('generatedAt is normalized to UTC', () {
    final r = Reflection(
      weekStart: DateTime(2026, 7, 20),
      generatedAt: DateTime.utc(2026, 7, 26, 9),
    );

    expect(r.generatedAt.isUtc, isTrue);
  });
}
