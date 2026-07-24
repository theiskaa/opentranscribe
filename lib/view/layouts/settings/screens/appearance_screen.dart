import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/app_icons.dart';
import 'package:opentranscribe/core/theming/app_theme_mode.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/app_scaffold.dart';
import 'package:opentranscribe/view/widgets/settings_kit.dart';

/// Appearance: reeed's shape. A "Match system" toggle up top, then the Light and
/// Dark modes as separate labelled groups of preview cards. Matching system
/// follows the platform; turning it off pins one mode. With one palette per mode
/// today, each group holds a single card - more themes slot in as more cards.
class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    final themeCubit = context.watch<ThemeCubit>();
    final state = themeCubit.state;
    final matchSystem = state.mode == AppThemeMode.system;

    return AppScaffold(
      background: theme.screens.settings,
      onBack: () => context.pop(),
      child: SettingsList(
        children: [
          SettingsCard(
            children: [
              SettingsToggle(
                icon: AppIcons.moonFill,
                title: l10n.themeMatchSystem,
                value: matchSystem,
                // Off drops to the mode the system is currently showing, so
                // nothing visibly jumps as the switch flips.
                onChanged: (on) => themeCubit.setMode(
                  on
                      ? AppThemeMode.system
                      : (state.platformBrightness == Brightness.dark
                            ? AppThemeMode.dark
                            : AppThemeMode.light),
                ),
              ),
            ],
          ),
          SectionLabel(l10n.themeLight),
          SettingsCard(
            children: [
              _ModeGroup(
                cards: [
                  ThemeModeCard(
                    label: l10n.themeLight,
                    selected: !matchSystem && state.mode == AppThemeMode.light,
                    onTap: () => themeCubit.setMode(AppThemeMode.light),
                    background: state.light.background,
                    foreground: state.light.text,
                  ),
                ],
              ),
            ],
          ),
          SectionLabel(l10n.themeDark),
          SettingsCard(
            children: [
              _ModeGroup(
                cards: [
                  ThemeModeCard(
                    label: l10n.themeDark,
                    selected: !matchSystem && state.mode == AppThemeMode.dark,
                    onTap: () => themeCubit.setMode(AppThemeMode.dark),
                    background: state.dark.background,
                    foreground: state.dark.text,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The theme cards inside a group card, wrapped at a fixed width so a group can
/// grow past one without stretching.
class _ModeGroup extends StatelessWidget {
  const _ModeGroup({required this.cards});

  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      // Full width so the cards sit at the LEFT edge; the SettingsCard's Column
      // centres anything narrower than itself, and a bare Wrap is narrower.
      child: SizedBox(
        width: double.infinity,
        child: Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [for (final card in cards) SizedBox(width: 76, child: card)],
        ),
      ),
    );
  }
}
