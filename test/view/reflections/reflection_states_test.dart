import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/models/reflection_timeline.dart';
import 'package:opentranscribe/core/reflect/reflection_engine.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/layouts/reflections/components/reflection_states.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  test('reflectionEditorialCopy invites on the first run when the model is available', () {
    expect(
      reflectionEditorialCopy(
        l10n,
        available: true,
        status: ReflectionAvailabilityStatus.available,
      ),
      (l10n.reflectionsEmptyTitle, l10n.reflectionsEmptyBody),
    );
  });

  test('reflectionEditorialCopy explains each unavailable state', () {
    expect(
      reflectionEditorialCopy(
        l10n,
        available: false,
        status: ReflectionAvailabilityStatus.notEnabled,
      ),
      (l10n.reflectionOffTitle, l10n.reflectionOffBody),
    );
    expect(
      reflectionEditorialCopy(
        l10n,
        available: false,
        status: ReflectionAvailabilityStatus.modelNotReady,
      ),
      (l10n.reflectionPreparingTitle, l10n.reflectionPreparingBody),
    );
    for (final status in const [
      ReflectionAvailabilityStatus.deviceNotEligible,
      ReflectionAvailabilityStatus.unsupported,
    ]) {
      expect(reflectionEditorialCopy(l10n, available: false, status: status), (
        l10n.reflectionUnsupportedTitle,
        l10n.reflectionUnsupportedBody,
      ), reason: '$status');
    }
  });

  test('reflectionWeekPlaceholder is null for a reflected week', () {
    expect(reflectionWeekPlaceholder(l10n, ReflectionWeekStatus.reflected), isNull);
  });

  test('reflectionWeekPlaceholder marks only a recorded silence', () {
    expect(reflectionWeekPlaceholder(l10n, ReflectionWeekStatus.silent)?.marker, isTrue);
    expect(reflectionWeekPlaceholder(l10n, ReflectionWeekStatus.erased)?.marker, isFalse);
    expect(reflectionWeekPlaceholder(l10n, ReflectionWeekStatus.unreflected)?.marker, isFalse);
  });

  test('reflectionWeekPlaceholder gives each state its own title', () {
    expect(
      reflectionWeekPlaceholder(l10n, ReflectionWeekStatus.silent)?.title,
      l10n.reflectionQuietWeek,
    );
    expect(
      reflectionWeekPlaceholder(l10n, ReflectionWeekStatus.erased)?.title,
      l10n.reflectionErasedTitle,
    );
    expect(
      reflectionWeekPlaceholder(l10n, ReflectionWeekStatus.unreflected)?.title,
      l10n.reflectionWaitingTitle,
    );
  });
}
