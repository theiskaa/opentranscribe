import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:opentranscribe/core/routes/routes.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/app_icons.dart';
import 'package:opentranscribe/core/theming/app_theme.dart';
import 'package:opentranscribe/core/theming/app_theme_family.dart';
import 'package:opentranscribe/core/theming/app_theme_mode.dart';
import 'package:opentranscribe/core/utils/url.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/app_scaffold.dart';
import 'package:opentranscribe/view/widgets/segmented_control.dart';
import 'package:opentranscribe/view/widgets/settings_kit.dart';

/// Appearance: two independent axes. A System / Light / Dark segment picks HOW
/// the appearance is decided; the theme grid picks WHICH family. They do not
/// interfere - choosing Gruvbox with System on keeps following the platform, so
/// light uses gruvbox-light and dark uses gruvbox-dark. Each family card previews
/// in the currently resolved appearance.
class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    final themeCubit = context.watch<ThemeCubit>();
    final state = themeCubit.state;

    return AppScaffold(
      background: theme.screens.settings,
      onBack: () => context.pop(),
      child: SettingsList(
        children: [
          SectionLabel(l10n.settingsAppearance),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: _ModeSelector(mode: state.mode, onChanged: themeCubit.setMode),
          ),
          SectionLabel(l10n.settingsTheme),
          _FamilyGroup(families: AppThemeFamily.all),
          const SizedBox(height: AppSpacing.md),
          SectionInfoLink(
            text: l10n.themeRequestInfo,
            linkLabel: l10n.themeRequestLink,
            icon: AppIcons.arrowUpRight,
            onTap: () => unawaited(openLink(kNewIssueUrl)),
          ),
        ],
      ),
    );
  }
}

/// A three-way appearance switch: System / Light / Dark, on the app's
/// segmented control.
class _ModeSelector extends StatelessWidget {
  const _ModeSelector({required this.mode, required this.onChanged});

  final AppThemeMode mode;
  final ValueChanged<AppThemeMode> onChanged;

  static const _modes = [AppThemeMode.system, AppThemeMode.light, AppThemeMode.dark];

  String _label(AppThemeMode m, AppLocalizations l10n) => switch (m) {
    AppThemeMode.system => l10n.themeSystem,
    AppThemeMode.light => l10n.themeLight,
    AppThemeMode.dark => l10n.themeDark,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppSegmentedControl<AppThemeMode>(
      segments: [for (final m in _modes) (m, _label(m, l10n))],
      selected: mode,
      onChanged: onChanged,
    );
  }
}

/// One card per family, previewed in the currently resolved appearance so the
/// grid tracks the System/Light/Dark segment above it.
class _FamilyGroup extends StatelessWidget {
  const _FamilyGroup({required this.families});

  final Iterable<AppThemeFamily> families;

  String _name(String id, AppLocalizations l10n) => switch (id) {
    AppThemeFamily.gruvboxId => l10n.themeNameGruvbox,
    AppThemeFamily.solarizedId => l10n.themeNameSolarized,
    AppThemeFamily.sepiaId => l10n.themeNameSepia,
    AppThemeFamily.midnightId => l10n.themeNameMidnight,
    AppThemeFamily.emberId => l10n.themeNameEmber,
    AppThemeFamily.forestId => l10n.themeNameForest,
    AppThemeFamily.roseId => l10n.themeNameRose,
    _ => l10n.themeNameDefault,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cubit = context.watch<ThemeCubit>();
    final state = cubit.state;
    return SettingsCard(
      children: [
        _FamilyGrid(
          cards: [
            for (final family in families)
              _FamilyCard(
                family: family,
                variant: family.resolve(wantDark: state.wantDark),
                label: _name(family.id, l10n),
                // Selection follows the worn family, so a stored club pick
                // reads as the default until the entitlement lands.
                selected: state.wornFamily.id == family.id,
                locked: family.club && !state.member,
                onPick: () => cubit.setFamily(family.id),
              ),
          ],
        ),
      ],
    );
  }
}

/// A locked card (a club look a non-member cannot wear yet) opens the club
/// instead of switching.
class _FamilyCard extends StatelessWidget {
  const _FamilyCard({
    required this.family,
    required this.variant,
    required this.label,
    required this.selected,
    required this.locked,
    required this.onPick,
  });

  final AppThemeFamily family;
  final AppTheme variant;
  final String label;
  final bool selected;
  final bool locked;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return ThemeFamilyCard(
      label: label,
      selected: selected,
      marked: locked,
      onTap: locked ? () => context.pushNamed(Routes.settingsSupportName) : onPick,
      background: variant.background,
      foreground: variant.text,
      accent: variant.accent,
      onAccent: variant.onAccent,
    );
  }
}

/// Lays the cards out in four equal columns that fill the row, so they scale
/// with the device width and every row, full or not, shares one card size.
class _FamilyGrid extends StatelessWidget {
  const _FamilyGrid({required this.cards});

  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    const spacing = AppSpacing.md;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const columns = 4;
          final itemWidth = (constraints.maxWidth - spacing * (columns - 1)) / columns;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: [for (final card in cards) SizedBox(width: itemWidth, child: card)],
          );
        },
      ),
    );
  }
}
