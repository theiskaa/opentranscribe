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
import 'package:opentranscribe/view/widgets/app_menu.dart';
import 'package:opentranscribe/view/widgets/settings_kit.dart';

/// Appearance: two independent axes. The bar's menu picks HOW the appearance
/// is decided (System / Light / Dark); the theme grid picks WHICH family. They
/// do not interfere - choosing Gruvbox with System on keeps following the
/// platform. Each family card previews in the currently resolved appearance.
class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    return AppScaffold(
      background: theme.screens.settings,
      onBack: () => context.pop(),
      actions: [_ModeMenu(color: theme.topBar.iconColor)],
      child: SettingsList(
        children: [
          const SizedBox(height: 10),
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

/// System / Light / Dark as a bar menu, the current one ticked. The glyph
/// follows the resolved appearance, so the bar says what is on before the
/// menu opens.
class _ModeMenu extends StatelessWidget {
  const _ModeMenu({required this.color});

  final Color color;

  static const _modes = [AppThemeMode.system, AppThemeMode.light, AppThemeMode.dark];

  String _label(AppThemeMode m, AppLocalizations l10n) => switch (m) {
    AppThemeMode.system => l10n.themeSystem,
    AppThemeMode.light => l10n.themeLight,
    AppThemeMode.dark => l10n.themeDark,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cubit = context.watch<ThemeCubit>();
    final state = cubit.state;
    return AppMenuButton(
      icon: state.wantDark ? AppIcons.moonFill : AppIcons.sunMax,
      // The sun and moon ink fatter than the ellipsis the size was tuned for.
      iconSize: 16,
      color: color,
      items: [
        for (final mode in _modes)
          AppMenuItem(id: mode.name, label: _label(mode, l10n), selected: state.mode == mode),
      ],
      onSelectedId: (id) =>
          unawaited(cubit.setMode(AppThemeMode.values.firstWhere((m) => m.name == id))),
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
    AppThemeFamily.sepiaId => l10n.themeNameSepia,
    AppThemeFamily.midnightId => l10n.themeNameMidnight,
    AppThemeFamily.draculaId => l10n.themeNameDracula,
    AppThemeFamily.nordId => l10n.themeNameNord,
    AppThemeFamily.catppuccinId => l10n.themeNameCatppuccin,
    AppThemeFamily.tokyoNightId => l10n.themeNameTokyoNight,
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
