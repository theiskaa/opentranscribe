import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:opentranscribe/core/models/reflection.dart';
import 'package:opentranscribe/core/reflect/reflection_engine.dart';
import 'package:opentranscribe/core/state/reflections_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/app_icons.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/core/utils/haptics.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/layouts/reflections/components/reflection_row.dart';
import 'package:opentranscribe/view/layouts/reflections/components/reflection_settings_menu.dart';
import 'package:opentranscribe/view/widgets/app_button.dart';
import 'package:opentranscribe/view/widgets/app_notice.dart';
import 'package:opentranscribe/view/widgets/app_scaffold.dart';
import 'package:opentranscribe/view/widgets/app_sheet.dart';
import 'package:opentranscribe/view/widgets/formatting.dart';
import 'package:opentranscribe/view/widgets/sheet_message.dart';

/// The weekly reflections history: past weeks newest first, each with a
/// regenerate/delete menu, and the preferences in the top-bar settings dropdown.
/// Reads the root-scoped [ReflectionsCubit]; the list refreshes itself when the
/// foreground catch-up writes a new reflection.
class ReflectionsScreen extends StatelessWidget {
  const ReflectionsScreen({super.key});

  Future<void> _confirmDelete(BuildContext context, Reflection reflection) async {
    final l10n = AppLocalizations.of(context)!;
    final cubit = context.read<ReflectionsCubit>();
    final confirmed = await showAppSheet<bool>(
      context,
      builder: (context) => SheetMessage(
        icon: AppIcons.trash,
        title: l10n.reflectionDeleteTitle,
        body: l10n.reflectionDeleteBody,
        action: AppButton(
          label: l10n.reflectionDelete,
          variant: AppButtonVariant.danger,
          onPressed: () {
            Haptics.medium();
            Navigator.of(context).pop(true);
          },
        ),
      ),
    );
    if ((confirmed ?? false) && context.mounted) unawaited(cubit.delete(reflection.weekStart));
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    final locale = localeTag(context);
    final cubit = context.watch<ReflectionsCubit>();
    final state = cubit.state;

    // Unless Apple Intelligence is ready, the screen explains the state and
    // offers the one action that helps (rather than being hidden). The settings
    // dropdown only appears when there is something to configure.
    if (!state.available) {
      return AppScaffold(
        background: theme.screens.settings,
        onBack: () => context.pop(),
        child: _Unavailable(status: state.availability.status),
      );
    }

    return AppScaffold(
      background: theme.screens.settings,
      onBack: () => context.pop(),
      actions: const [
        Padding(
          padding: EdgeInsets.only(top: AppSpacing.md),
          child: ReflectionSettingsMenu(),
        ),
      ],
      child: state.history.isEmpty
          ? const _Empty()
          : ListView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppScaffold.topPaddingOf(context),
                AppSpacing.md,
                MediaQuery.paddingOf(context).bottom + AppSpacing.xxl,
              ),
              children: [
                AppNotice(
                  message: state.regenerateFailed ? l10n.reflectionRegenerateFailed : null,
                  onDismiss: cubit.clearRegenerateFailed,
                ),
                for (final reflection in state.history) ...[
                  ReflectionRow(
                    reflection: reflection,
                    regenerating: state.regenerating == reflection.weekStart,
                    onRegenerate: () => unawaited(cubit.regenerate(reflection.weekStart)),
                    onDelete: () => unawaited(_confirmDelete(context, reflection)),
                    locale: locale,
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ],
            ),
    );
  }
}

/// The first-run state: nothing reflected yet. A title and a line of writing at
/// the top left, the same first-page-of-the-journal vocabulary as home's empty
/// state, not a card floated in the middle. Scrollable so it sits under the
/// frosted bar like the list it replaces.
class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppScaffold.topPaddingOf(context) + AppSpacing.xxxl,
        AppSpacing.xxxl,
        AppSpacing.xxl,
      ),
      children: [
        Text(l10n.reflectionsEmptyTitle, style: AppType.display.copyWith(color: theme.text)),
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.reflectionsEmptyBody,
          style: AppType.body.copyWith(color: theme.textSecondary, height: 1.4),
        ),
      ],
    );
  }
}

/// Shown when Apple Intelligence is not ready: the state, and the one action
/// that helps. Off -> a Settings jump (iOS has no deep-link to the Apple
/// Intelligence pane, so it lands on the Settings app); preparing and
/// unsupported are informational. Same editorial voice as the empty state.
class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.status});

  final ReflectionAvailabilityStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    // Instructions only: iOS has no public URL to the Apple Intelligence & Siri
    // pane (only the app's own Settings page), so a button would land the user
    // in the wrong place. The body says exactly where to go instead.
    final (title, body) = switch (status) {
      ReflectionAvailabilityStatus.notEnabled => (l10n.reflectionOffTitle, l10n.reflectionOffBody),
      ReflectionAvailabilityStatus.modelNotReady => (
        l10n.reflectionPreparingTitle,
        l10n.reflectionPreparingBody,
      ),
      // deviceNotEligible, unsupported (and the unreachable available).
      _ => (l10n.reflectionUnsupportedTitle, l10n.reflectionUnsupportedBody),
    };

    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppScaffold.topPaddingOf(context) + AppSpacing.xxxl,
        AppSpacing.xxxl,
        AppSpacing.xxl,
      ),
      children: [
        Text(title, style: AppType.display.copyWith(color: theme.text)),
        const SizedBox(height: AppSpacing.md),
        Text(body, style: AppType.body.copyWith(color: theme.textSecondary, height: 1.4)),
      ],
    );
  }
}
