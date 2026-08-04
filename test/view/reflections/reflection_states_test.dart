import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/models/reflection_timeline.dart';
import 'package:opentranscribe/core/reflect/reflection_engine.dart';
import 'package:opentranscribe/core/reflect/reflection_period.dart';
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

  test('reflectionPlaceholderContent is null for a reflected week', () {
    expect(
      reflectionPlaceholderContent(l10n, ReflectionPageStatus.reflected, ReflectionPeriod.weekly),
      isNull,
    );
  });

  test('reflectionPlaceholderContent marks only a recorded silence', () {
    const p = ReflectionPeriod.weekly;
    expect(reflectionPlaceholderContent(l10n, ReflectionPageStatus.silent, p)?.marker, isTrue);
    expect(reflectionPlaceholderContent(l10n, ReflectionPageStatus.erased, p)?.marker, isFalse);
    expect(
      reflectionPlaceholderContent(l10n, ReflectionPageStatus.unreflected, p)?.marker,
      isFalse,
    );
  });

  test('reflectionPlaceholderContent gives each state its own title', () {
    const p = ReflectionPeriod.weekly;
    expect(
      reflectionPlaceholderContent(l10n, ReflectionPageStatus.silent, p)?.title,
      l10n.reflectionQuietWeek,
    );
    expect(
      reflectionPlaceholderContent(l10n, ReflectionPageStatus.erased, p)?.title,
      l10n.reflectionErasedTitle,
    );
    expect(
      reflectionPlaceholderContent(l10n, ReflectionPageStatus.unreflected, p)?.title,
      l10n.reflectionWaitingTitle,
    );
  });

  test('reflectionPlaceholderContent names the silence after the viewed period', () {
    expect(
      reflectionPlaceholderContent(
        l10n,
        ReflectionPageStatus.silent,
        ReflectionPeriod.daily,
      )?.title,
      l10n.reflectionQuietDay,
    );
    expect(
      reflectionPlaceholderContent(
        l10n,
        ReflectionPageStatus.silent,
        ReflectionPeriod.monthly,
      )?.title,
      l10n.reflectionQuietMonth,
    );
  });
}
