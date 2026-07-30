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
///
/// Availability gates only the generation affordances (the settings dropdown,
/// per-row regenerate), never stored history: home keeps showing the cards, so
/// hiding their text here would strand what the user can already see. With no
/// history the screen is a single editorial page, explaining either the empty
/// first run or how to make the feature work.
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

  /// The editorial copy for a history-less screen: the first-run invitation
  /// when the model runs here, else the state and what would make it work.
  /// Instructions only for the off state: iOS has no public URL to the Apple
  /// Intelligence & Siri pane (only the app's own Settings page), so a button
  /// would land the user in the wrong place; the body says where to go instead.
  (String, String) _editorialCopy(AppLocalizations l10n, ReflectionsState state) {
    if (state.available) return (l10n.reflectionsEmptyTitle, l10n.reflectionsEmptyBody);
    return switch (state.availability.status) {
      ReflectionAvailabilityStatus.notEnabled => (l10n.reflectionOffTitle, l10n.reflectionOffBody),
      ReflectionAvailabilityStatus.modelNotReady => (
        l10n.reflectionPreparingTitle,
        l10n.reflectionPreparingBody,
      ),
      // deviceNotEligible, unsupported (and the unreachable available).
      _ => (l10n.reflectionUnsupportedTitle, l10n.reflectionUnsupportedBody),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    final locale = localeTag(context);
    final cubit = context.watch<ReflectionsCubit>();
    final state = cubit.state;

    return AppScaffold(
      background: theme.screens.settings,
      onBack: () => context.pop(),
      actions: [
        // Nothing to configure while the model cannot run; the editorial page
        // below explains instead.
        if (state.available)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: ReflectionSettingsMenu(color: theme.topBar.iconColor),
          ),
      ],
      child: state.history.isEmpty
          ? _Editorial(copy: _editorialCopy(l10n, state))
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
                    canRegenerate: state.available,
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

/// The screen's editorial page: a display title and a line of writing at the
/// top left, the same first-page-of-the-journal vocabulary as home's empty
/// state, not a card floated in the middle. Scrollable so it sits under the
/// frosted bar like the list it replaces.
class _Editorial extends StatelessWidget {
  const _Editorial({required this.copy});

  final (String, String) copy;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final (title, body) = copy;
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
