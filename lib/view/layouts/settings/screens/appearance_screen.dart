import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/app_icons.dart';
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

  String _familyName(String id, AppLocalizations l10n) => switch (id) {
    AppThemeFamily.gruvboxId => l10n.themeNameGruvbox,
    AppThemeFamily.solarizedId => l10n.themeNameSolarized,
    AppThemeFamily.sepiaId => l10n.themeNameSepia,
    _ => l10n.themeNameDefault,
  };

  Widget _familyCard(
    AppThemeFamily family,
    ThemeState state,
    ThemeCubit cubit,
    AppLocalizations l10n,
  ) {
    // Preview in the currently resolved appearance, so the grid tracks the
    // System/Light/Dark segment above it.
    final variant = family.resolve(wantDark: state.wantDark);
    return ThemeFamilyCard(
      label: _familyName(family.id, l10n),
      selected: state.familyId == family.id,
      onTap: () => cubit.setFamily(family.id),
      background: variant.background,
      foreground: variant.text,
      accent: variant.accent,
      onAccent: variant.onAccent,
    );
  }

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
          SettingsCard(
            children: [
              _FamilyGrid(
                cards: [
                  for (final family in AppThemeFamily.all)
                    _familyCard(family, state, themeCubit, l10n),
                ],
              ),
            ],
          ),
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

/// Lays the theme cards out in equal columns that fill the row, so they scale
/// with the device width and never leave an orphan on a second line.
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
          final columns = cards.length < 4 ? cards.length : 4;
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
