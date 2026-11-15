import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/state/notifications_cubit.dart';
import 'package:opentranscribe/view/layouts/settings/screens/notifications_screen.dart';
import 'package:reflections/reflections.dart';

void main() {
  const weekly = {ReflectionPeriod.weekly: NotificationSlot(reflectionEnabled: true)};

  test('an unsupported device is told so, never offered the turn-on link', () {
    const state = NotificationsState(reflectionsAvailable: false);
    expect(remindersFootnoteOf(state), RemindersFootnote.unavailable);
  });

  test('a device that can reflect with every period off is offered the turn-on link', () {
    const state = NotificationsState();
    expect(remindersFootnoteOf(state), RemindersFootnote.needsReflections);
  });

  test('a period that reflects leaves the plain explanation', () {
    const state = NotificationsState(slots: weekly);
    expect(remindersFootnoteOf(state), RemindersFootnote.info);
  });

  group('the next line ticks on the minute', () {
    test('mid-minute, it waits out the rest of the minute', () {
      expect(
        untilNextMinute(DateTime(2026, 11, 15, 9, 41, 20, 250)),
        const Duration(seconds: 39, milliseconds: 750),
      );
    });

    test('exactly on a minute, it waits a whole one rather than none', () {
      expect(untilNextMinute(DateTime(2026, 11, 15, 9, 41)), const Duration(minutes: 1));
    });

    test('just before a minute, it waits only the sliver left', () {
      expect(
        untilNextMinute(DateTime(2026, 11, 15, 9, 41, 59, 999, 999)),
        const Duration(microseconds: 1),
      );
    });
  });
}
