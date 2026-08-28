import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:opentranscribe/core/app/deps.dart';
import 'package:opentranscribe/core/models/app_icon_descriptor.dart';
import 'package:opentranscribe/core/routes/routes.dart';
import 'package:opentranscribe/core/state/app_icon_cubit.dart';
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
import 'package:opentranscribe/view/widgets/app_sheet.dart';
import 'package:opentranscribe/view/widgets/settings_kit.dart';
import 'package:opentranscribe/view/widgets/sheet_message.dart';

/// Appearance: two independent axes. The bar's menu picks HOW the appearance
/// is decided (System / Light / Dark); the theme grid picks WHICH family. They
/// do not interfere - choosing Gruvbox with System on keeps following the
/// platform. Each family card previews in the currently resolved appearance.
class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AppIconCubit(
        store: Deps.i.appIconStore,
        options: Deps.i.appIconDescriptors,
        isSupporter: () => Deps.i.supportService.tier.isSupporter,
        tierChanges: Deps.i.supportService.changes,
      )..load(),
      child: const _AppearanceView(),
    );
  }
}

class _AppearanceView extends StatelessWidget {
  const _AppearanceView();

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
          SectionLabel(l10n.appearanceIconSection),
          const _IconGroup(),
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

/// The home screen icons, in the family grid's columns so the two pickers
/// read as one. A locked icon opens the club like a locked family does.
class _IconGroup extends StatelessWidget {
  const _IconGroup();

  Future<void> _pick(BuildContext context, AppIconDescriptor option) async {
    final outcome = await context.read<AppIconCubit>().pick(option.id);
    if (!context.mounted) return;
    switch (outcome) {
      case AppIconPickOutcome.locked:
        unawaited(context.pushNamed(Routes.settingsSupportName));
      case AppIconPickOutcome.failed:
        final l10n = AppLocalizations.of(context)!;
        await showAppSheet<void>(
          context,
          builder: (context) => SheetMessage(
            icon: AppIcons.xmark,
            title: l10n.appIconFailedTitle,
            body: l10n.appIconFailedBody,
          ),
        );
      case AppIconPickOutcome.switched || AppIconPickOutcome.unchanged:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = context.watch<AppIconCubit>().state;
    return SettingsCard(
      children: [
        _FamilyGrid(
          cards: [
            for (final option in state.options)
              _IconCard(
                label: option.name(l10n),
                preview: option.preview,
                selected: option.id == state.currentId,
                locked: option.club && !state.member,
                onTap: () => _pick(context, option),
              ),
          ],
        ),
      ],
    );
  }
}

/// Square, unlike the family cards: a home screen icon is.
class _IconCard extends StatelessWidget {
  const _IconCard({
    required this.label,
    required this.preview,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  final String label;
  final String preview;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return ThemeFamilyCard(
      label: label,
      selected: selected,
      marked: locked,
      onTap: onTap,
      accent: theme.accent,
      onAccent: theme.onAccent,
      aspectRatio: 1,
      child: Image.asset(preview, fit: BoxFit.cover),
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
