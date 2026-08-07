import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/models/reflection.dart';
import 'package:opentranscribe/core/reflect/reflection_options.dart';
import 'package:opentranscribe/core/reflect/reflection_period.dart';

void main() {
  test('round-trips a written reflection through JSON', () {
    final r = Reflection(
      periodStart: DateTime(2026, 7, 20),
      generatedAt: DateTime.utc(2026, 7, 26, 9),
      text: 'Work threaded through most of the week.',
      voice: ReflectionVoice.literary,
    );

    expect(Reflection.fromJson(r.toJson()), r);
  });

  test('round-trips a silent reflection: null text survives as silence', () {
    final r = Reflection(
      periodStart: DateTime(2026, 7, 20),
      generatedAt: DateTime.utc(2026, 7, 26, 9),
    );

    final back = Reflection.fromJson(r.toJson());
    expect(back, r);
    expect(back.isSilent, isTrue);
    expect(r.toJson().containsKey('text'), isFalse);
  });

  test('periodStart is a civil date: time and timezone are dropped', () {
    final r = Reflection(
      periodStart: DateTime(2026, 7, 20, 23, 59),
      generatedAt: DateTime.utc(2026, 7, 26),
    );

    expect(r.periodStart, DateTime(2026, 7, 20));
    expect(r.periodKey, '2026-07-20');
  });

  test('an unrecognized stored voice reads back as null, not a throw', () {
    final json = {
      'periodStart': '2026-07-20',
      'generatedAt': DateTime.utc(2026, 7, 26).toIso8601String(),
      'text': 'x',
      'voice': 'from_a_future_build',
    };

    expect(Reflection.fromJson(json).voice, isNull);
  });

  test('generatedAt is normalized to UTC', () {
    final r = Reflection(
      periodStart: DateTime(2026, 7, 20),
      generatedAt: DateTime.utc(2026, 7, 26, 9),
    );

    expect(r.generatedAt.isUtc, isTrue);
  });

  test('round-trips its period through JSON', () {
    final r = Reflection(
      periodStart: DateTime(2026, 8),
      generatedAt: DateTime.utc(2026, 8, 1, 9),
      period: ReflectionPeriod.monthly,
      text: 'August held steady.',
    );

    expect(Reflection.fromJson(r.toJson()).period, ReflectionPeriod.monthly);
    expect(Reflection.fromJson(r.toJson()), r);
  });

  test('a record with no period reads back as weekly', () {
    final json = {
      'periodStart': '2026-07-20',
      'generatedAt': DateTime.utc(2026, 7, 26).toIso8601String(),
      'text': 'x',
    };

    expect(Reflection.fromJson(json).period, ReflectionPeriod.weekly);
  });

  test('the same start under two periods is two distinct records', () {
    final at = DateTime.utc(2026, 8, 3);
    final day = Reflection(
      periodStart: DateTime(2026, 8, 3),
      generatedAt: at,
      period: ReflectionPeriod.daily,
    );
    final week = Reflection(periodStart: DateTime(2026, 8, 3), generatedAt: at);

    expect(day == week, isFalse);
    expect(day.hashCode == week.hashCode, isFalse);
  });
}
