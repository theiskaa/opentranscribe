import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/models/reflection.dart';
import 'package:opentranscribe/core/reflect/reflection_period.dart';
import 'package:opentranscribe/view/layouts/home/components/reflection_home_card.dart';

Reflection reflection(
  DateTime start, {
  ReflectionPeriod period = ReflectionPeriod.weekly,
  String? text,
}) => Reflection(
  periodStart: start,
  period: period,
  generatedAt: DateTime.utc(2026, 8, 3),
  text: text,
);

void main() {
  final today = DateTime(2026, 7, 29);

  test('the open week (the one containing today) is never carded', () {
    final cards = reflectionCardsForSections(
      sectionDays: [DateTime(2026, 7, 29), DateTime(2026, 7, 28)],
      reflections: [reflection(DateTime(2026, 7, 27), text: 'this week')],
      today: today,
    );
    expect(cards, isEmpty);
  });

  test('a finished week cards above its first (most recent) in-range section', () {
    final cards = reflectionCardsForSections(
      sectionDays: [DateTime(2026, 7, 28), DateTime(2026, 7, 24), DateTime(2026, 7, 22)],
      reflections: [reflection(DateTime(2026, 7, 20), text: 'last week')],
      today: today,
    );
    expect(cards.keys, [1]);
    expect(cards[1]!.single.text, 'last week');
  });

  test('a period with no stored reflection gets no card', () {
    final cards = reflectionCardsForSections(
      sectionDays: [DateTime(2026, 7, 22)],
      reflections: const [],
      today: today,
    );
    expect(cards, isEmpty);
  });

  test('silent and written weeks both place a card', () {
    final cards = reflectionCardsForSections(
      sectionDays: [DateTime(2026, 7, 22), DateTime(2026, 7, 15)],
      reflections: [
        reflection(DateTime(2026, 7, 20), text: 'written'),
        reflection(DateTime(2026, 7, 13)),
      ],
      today: today,
    );
    expect(cards[0]!.single.text, 'written');
    expect(cards[1]!.single.isSilent, isTrue);
  });

  test('matches by the stored week range even if the boundary later shifts', () {
    final cards = reflectionCardsForSections(
      sectionDays: [DateTime(2026, 7, 22), DateTime(2026, 7, 20)],
      reflections: [reflection(DateTime(2026, 7, 19), text: 'sunday week')],
      today: today,
    );
    expect(cards[0]!.single.text, 'sunday week');
  });

  test('a daily card lands on its own day, once', () {
    final cards = reflectionCardsForSections(
      sectionDays: [DateTime(2026, 7, 28), DateTime(2026, 7, 27)],
      reflections: [
        reflection(DateTime(2026, 7, 27), period: ReflectionPeriod.daily, text: 'that day'),
      ],
      today: today,
    );
    expect(cards.keys, [1]);
    expect(cards[1]!.single.text, 'that day');
  });

  test('the open month is never carded, a closed month is', () {
    final cards = reflectionCardsForSections(
      sectionDays: [DateTime(2026, 7, 5), DateTime(2026, 6, 20)],
      reflections: [
        reflection(DateTime(2026, 7), period: ReflectionPeriod.monthly, text: 'open july'),
        reflection(DateTime(2026, 6), period: ReflectionPeriod.monthly, text: 'closed june'),
      ],
      today: today,
    );
    expect(cards.keys, [1]);
    expect(cards[1]!.single.text, 'closed june');
  });

  test('a month, its week, and a day stack on one section, broad to narrow', () {
    final cards = reflectionCardsForSections(
      sectionDays: [DateTime(2026, 6)],
      reflections: [
        reflection(DateTime(2026, 6), period: ReflectionPeriod.monthly, text: 'june'),
        reflection(DateTime(2026, 6), period: ReflectionPeriod.daily, text: 'the 1st'),
        reflection(DateTime(2026, 6), text: 'first week'),
      ],
      today: today,
    );
    expect(cards[0]!.map((r) => r.text), ['june', 'first week', 'the 1st']);
  });

  group('newlyReflected (the entrance diff)', () {
    test('detects an added card and ignores reorder', () {
      final a = reflection(DateTime(2026, 7, 13), text: 'a');
      final b = reflection(DateTime(2026, 7, 20), text: 'b');
      expect(newlyReflected([a], [b, a]), {(ReflectionPeriod.weekly, DateTime(2026, 7, 20))});
      expect(newlyReflected([a, b], [b, a]), isEmpty);
    });

    test('a regenerated card (same key, new generatedAt) is not new on home: '
        'its arrival plays on the reflections surfaces instead', () {
      final before = reflection(DateTime(2026, 7, 20), text: 'old');
      final after = Reflection(
        periodStart: DateTime(2026, 7, 20),
        generatedAt: DateTime.utc(2026, 8, 4),
        text: 'new',
      );
      expect(newlyReflected([before], [after]), isEmpty);
    });

    test('a removed card is not new', () {
      final a = reflection(DateTime(2026, 7, 13), text: 'a');
      final b = reflection(DateTime(2026, 7, 20), text: 'b');
      expect(newlyReflected([a, b], [a]), isEmpty);
    });

    test('the same start under two periods is two distinct cards', () {
      final day = reflection(DateTime(2026, 7, 20), period: ReflectionPeriod.daily, text: 'day');
      final week = reflection(DateTime(2026, 7, 20), text: 'week');
      expect(newlyReflected([week], [week, day]), {
        (ReflectionPeriod.daily, DateTime(2026, 7, 20)),
      });
    });
  });
}
