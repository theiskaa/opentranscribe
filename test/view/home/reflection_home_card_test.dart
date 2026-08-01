import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/models/reflection.dart';
import 'package:opentranscribe/view/layouts/home/components/reflection_home_card.dart';

Reflection reflection(DateTime weekStart, {String? text}) =>
    Reflection(weekStart: weekStart, generatedAt: DateTime.utc(2026, 8, 3), text: text);

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
    expect(cards[1]!.text, 'last week');
  });

  test('a week with no stored reflection gets no card', () {
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
    expect(cards[0]!.text, 'written');
    expect(cards[1]!.isSilent, isTrue);
  });

  test('matches by the stored week range even if the boundary later shifts', () {
    final cards = reflectionCardsForSections(
      sectionDays: [DateTime(2026, 7, 22), DateTime(2026, 7, 20)],
      reflections: [reflection(DateTime(2026, 7, 19), text: 'sunday week')],
      today: today,
    );
    expect(cards[0]!.text, 'sunday week');
  });

  group('newlyReflectedWeeks (the entrance diff)', () {
    test('detects an added week and ignores reorder', () {
      final a = reflection(DateTime(2026, 7, 13), text: 'a');
      final b = reflection(DateTime(2026, 7, 20), text: 'b');
      expect(newlyReflectedWeeks([a], [b, a]), {DateTime(2026, 7, 20)});
      expect(newlyReflectedWeeks([a, b], [b, a]), isEmpty);
    });

    test('a regenerated week (same start, new generatedAt) is not new on home: '
        'its arrival plays on the reflections surfaces instead', () {
      final before = reflection(DateTime(2026, 7, 20), text: 'old');
      final after = Reflection(
        weekStart: DateTime(2026, 7, 20),
        generatedAt: DateTime.utc(2026, 8, 4),
        text: 'new',
      );
      expect(newlyReflectedWeeks([before], [after]), isEmpty);
    });

    test('a removed week is not new', () {
      final a = reflection(DateTime(2026, 7, 13), text: 'a');
      final b = reflection(DateTime(2026, 7, 20), text: 'b');
      expect(newlyReflectedWeeks([a, b], [a]), isEmpty);
    });
  });
}
