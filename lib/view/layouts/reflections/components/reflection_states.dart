import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/models/reflection_timeline.dart';
import 'package:opentranscribe/core/reflect/reflection_engine.dart';
import 'package:opentranscribe/core/reflect/reflection_period.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/formatting.dart';

/// The editorial copy for an empty timeline: the first-run invitation when the
/// model runs here, otherwise the state and what would make it work. The off
/// and unsupported states are instructions only, never a button: iOS has no
/// public URL to the Apple Intelligence pane, so a button would land the user
/// in the wrong place.
(String, String) reflectionEditorialCopy(
  AppLocalizations l10n, {
  required bool available,
  required ReflectionAvailabilityStatus status,
}) {
  if (available) return (l10n.reflectionsEmptyTitle, l10n.reflectionsEmptyBody);
  return switch (status) {
    ReflectionAvailabilityStatus.notEnabled => (l10n.reflectionOffTitle, l10n.reflectionOffBody),
    ReflectionAvailabilityStatus.modelNotReady => (
      l10n.reflectionPreparingTitle,
      l10n.reflectionPreparingBody,
    ),
    // available never reaches here (guarded above); it shares the arm only to
    // keep the switch exhaustive without a default.
    ReflectionAvailabilityStatus.available ||
    ReflectionAvailabilityStatus.deviceNotEligible ||
    ReflectionAvailabilityStatus.unsupported => (
      l10n.reflectionUnsupportedTitle,
      l10n.reflectionUnsupportedBody,
    ),
  };
}

/// The title and body a page shows when it holds no reflection text to read: a
/// quiet period the model recorded, a page the user erased, or one still
/// waiting for the next catch-up. The quiet marker names the viewed [period] so
/// a day, week, and month each read as themselves. Null for a reflected page,
/// whose text renders through the ink reveal instead.
({String title, String body, bool marker})? reflectionPlaceholderContent(
  AppLocalizations l10n,
  ReflectionPageStatus status,
  ReflectionPeriod period,
) => switch (status) {
  ReflectionPageStatus.reflected => null,
  // The bullet marks a silence the model recorded; the erased page drops it,
  // an absence the user authored, not one the period held.
  ReflectionPageStatus.silent => (
    title: reflectionQuietLabel(l10n, period),
    body: l10n.reflectionQuietBody,
    marker: true,
  ),
  ReflectionPageStatus.erased => (
    title: l10n.reflectionErasedTitle,
    body: l10n.reflectionErasedBody,
    marker: false,
  ),
  ReflectionPageStatus.unreflected => (
    title: l10n.reflectionWaitingTitle,
    body: l10n.reflectionWaitingBody,
    marker: false,
  ),
};

/// The editorial page's content: a display title over a line of writing, the
/// same first-page-of-the-journal voice as home's empty state. The scroll and
/// padding belong to the caller.
class ReflectionEditorialBody extends StatelessWidget {
  const ReflectionEditorialBody({required this.copy, super.key});

  final (String, String) copy;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final (title, body) = copy;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppType.display.copyWith(color: theme.text)),
        const SizedBox(height: AppSpacing.md),
        Text(body, style: AppType.body.copyWith(color: theme.textSecondary, height: 1.4)),
      ],
    );
  }
}

/// A page with no reflection to read: its [title] over a [body], with an
/// optional bullet [marker] for a recorded silence. Left-aligned in the page's
/// own flow under the range title.
class ReflectionPlaceholder extends StatelessWidget {
  const ReflectionPlaceholder({
    required this.title,
    required this.body,
    required this.marker,
    super.key,
  });

  final String title;
  final String body;
  final bool marker;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final titleStyle = AppType.title.copyWith(color: theme.textSecondary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (marker) ...[Text('·', style: titleStyle), const SizedBox(width: AppSpacing.sm)],
            Flexible(child: Text(title, style: titleStyle)),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(body, style: AppType.subhead.copyWith(color: theme.textSecondary, height: 1.4)),
      ],
    );
  }
}
