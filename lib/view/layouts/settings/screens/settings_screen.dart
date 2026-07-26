import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:opentranscribe/core/routes/routes.dart';
import 'package:opentranscribe/core/state/app_language_cubit.dart';
import 'package:opentranscribe/core/state/settings_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/app_icons.dart';
import 'package:opentranscribe/core/theming/app_theme_mode.dart';
import 'package:opentranscribe/core/utils/url.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/app_scaffold.dart';
import 'package:opentranscribe/view/widgets/brand_icon.dart';
import 'package:opentranscribe/view/widgets/locale_names.dart';
import 'package:opentranscribe/view/widgets/settings_kit.dart';
import 'package:opentranscribe/view/widgets/version_footer.dart';

const _repoUrl = 'github.com/theiskaa/opentranscribe';
const _authorUrl = 'x.com/theiskaa';

/// Settings: transcription language and model, storage, appearance, and about.
/// Nothing here uploads anything; the About rows open PUBLIC links (a repo, a
/// profile) that carry no user data - the one place the app points outward.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<SettingsCubit>().load();
  }

  String _themeModeName(AppThemeMode mode, AppLocalizations l10n) => switch (mode) {
    AppThemeMode.system => l10n.themeSystem,
    AppThemeMode.light => l10n.themeLight,
    AppThemeMode.dark => l10n.themeDark,
  };

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    final themeMode = context.watch<ThemeCubit>().state.mode;

    return AppScaffold(
      // No title: the section headers carry the heading, the bar is just the
      // frosted back chevron. Pushed over home, so that chevron is automatic.
      background: theme.screens.settings,
      child: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          return SettingsList(
            children: [
              SectionLabel(l10n.settingsApp),
              SettingsCard(
                children: [
                  SettingsRow(
                    icon: AppIcons.moonFill,
                    title: l10n.settingsAppearance,
                    value: _themeModeName(themeMode, l10n),
                    chevron: true,
                    onTap: () => context.pushNamed(Routes.settingsAppearanceName),
                  ),
                  SettingsRow(
                    icon: AppIcons.textformat,
                    title: l10n.settingsAppLanguage,
                    value: localeDisplayName(context.watch<AppLanguageCubit>().state),
                    chevron: true,
                    onTap: () => context.pushNamed(Routes.settingsAppLanguageName),
                  ),
                ],
              ),
              SectionLabel(l10n.settingsTranscription),
              SettingsCard(
                children: [
                  // ONE row: languages and their models live together on the
                  // models screen (the globe there sets the default). The
                  // value names the current default so it reads at a glance.
                  SettingsRow(
                    icon: AppIcons.waveform,
                    title: l10n.settingsModels,
                    value: localeDisplayName(state.localeId),
                    chevron: true,
                    onTap: () => context.pushNamed(Routes.settingsModelsName),
                  ),
                ],
              ),
              // Storage / backup toggle, temporarily removed - kept for when the
              // backup-exclusion behaviour is finished. Do NOT delete.
              // SectionLabel(l10n.settingsStorage),
              // SettingsCard(
              //   children: [
              //     SettingsToggle(
              //       icon: AppIcons.icloud,
              //       title: l10n.settingsBackup,
              //       value: !state.backupExcluded,
              //       onChanged: (included) =>
              //           context.read<SettingsCubit>().setBackupExcluded(!included),
              //     ),
              //   ],
              // ),
              // Padding(
              //   padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, 0),
              //   child: Text(
              //     l10n.settingsOffline,
              //     style: AppType.footnote.copyWith(color: theme.textSecondary),
              //   ),
              // ),
              SectionLabel(l10n.settingsAbout),
              SettingsCard(
                children: [
                  SettingsRow(
                    iconWidget: BrandIcon(
                      BrandIcon.github,
                      size: 18,
                      color: theme.settings.iconColor,
                    ),
                    title: l10n.settingsOpenSource,
                    external: true,
                    onTap: () => openLink(_repoUrl),
                  ),
                  SettingsRow(
                    iconWidget: BrandIcon(BrandIcon.x, size: 16, color: theme.settings.iconColor),
                    title: l10n.settingsCreatedBy,
                    external: true,
                    onTap: () => openLink(_authorUrl),
                  ),
                ],
              ),
              // Debug builds only: the one door to the widget gallery.
              if (kDebugMode) ...[
                const SectionLabel('Developer'),
                SettingsCard(
                  children: [
                    SettingsRow(
                      icon: AppIcons.waveform,
                      title: 'Widget gallery',
                      chevron: true,
                      onTap: () => context.pushNamed(Routes.galleryName),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.xxxl),
              const VersionFooter(),
            ],
          );
        },
      ),
    );
  }
}
