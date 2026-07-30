import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/models/reflection.dart';
import 'package:opentranscribe/view/layouts/reflections/components/reflection_home_card.dart';

/// Placement matches a section's day into a reflection's stored 7-day range, so
/// it never depends on the current locale's week boundary. The widget is not
/// pumped.
Reflection reflection(DateTime weekStart, {String? text}) =>
    Reflection(weekStart: weekStart, generatedAt: DateTime.utc(2026, 8, 3), text: text);

void main() {
  // today = Wed 2026-07-29; open week is 07-27..08-02; last week 07-20..07-26.
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
    expect(cards.keys, [1]); // 07-24 is the first section inside 07-20..07-26
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
    // Reflection stored under a Sunday-first week (07-19..07-25). Its days still
    // resolve to the card by range, whatever the current locale's first-day is.
    final cards = reflectionCardsForSections(
      sectionDays: [DateTime(2026, 7, 22), DateTime(2026, 7, 20)],
      reflections: [reflection(DateTime(2026, 7, 19), text: 'sunday week')],
      today: today,
    );
    expect(cards[0]!.text, 'sunday week');
  });
}
