import 'dart:async';

import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:opentranscribe/core/app/app_version.dart';
import 'package:opentranscribe/core/routes/routes.dart';
import 'package:opentranscribe/core/state/app_language_cubit.dart';
import 'package:opentranscribe/core/state/settings_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/app_icons.dart';
import 'package:opentranscribe/core/theming/app_theme_mode.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/app_menu.dart';
import 'package:opentranscribe/view/widgets/app_scaffold.dart';
import 'package:opentranscribe/view/widgets/locale_names.dart';
import 'package:opentranscribe/view/widgets/settings_kit.dart';

const _repoAddress = 'github.com/theiskaa/opentranscribe';
const _authorHandle = 'x.com/theiskaa';

/// Settings: transcription language and model, storage, appearance, and about.
/// Nothing here opens a network connection; the about rows copy to the
/// clipboard instead of launching anything.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// Which about row briefly shows "Copied", and which copy owns the reset.
  String? _copied;
  int _copyToken = 0;

  @override
  void initState() {
    super.initState();
    // Runs once per app lifetime (the shell keeps branch state alive), which
    // is accepted: the cubit also reloads after every mutating action.
    context.read<SettingsCubit>().load();
  }

  Future<void> _copy(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    final token = ++_copyToken;
    setState(() => _copied = value);
    Future<void>.delayed(const Duration(seconds: 2), () {
      if (mounted && token == _copyToken) setState(() => _copied = null);
    });
  }

  /// The rows these menus hang off, so a menu opens ON its row rather than
  /// somewhere else on the screen.
  final GlobalKey _themeRow = GlobalKey();
  final GlobalKey _languageRow = GlobalKey();

  /// The tapped row's bounds in global space, for a menu to grow out of.
  Rect? _anchorOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _pickTheme(AppLocalizations l10n) async {
    final anchor = _anchorOf(_themeRow);
    if (anchor == null) return;
    final theme = context.read<ThemeCubit>();
    const modes = AppThemeMode.values;
    final index = await showAppMenu(
      context,
      anchor: anchor,
      items: [for (final mode in modes) AppMenuItem(label: _themeModeName(mode, l10n))],
    );
    if (index != null) unawaited(theme.setMode(modes[index]));
  }

  Future<void> _pickAppLanguage(AppLocalizations l10n) async {
    final anchor = _anchorOf(_languageRow);
    if (anchor == null) return;
    const locales = AppLocalizations.supportedLocales;
    final language = context.read<AppLanguageCubit>();
    final index = await showAppMenu(
      context,
      anchor: anchor,
      items: [
        for (final locale in locales) AppMenuItem(label: localeDisplayName(locale.toLanguageTag())),
      ],
    );
    if (index != null) unawaited(language.setLanguage(locales[index].languageCode));
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
    final themeMode = context.select<ThemeCubit, AppThemeMode>((c) => c.state.mode);

    return AppScaffold(
      title: l10n.settingsTitle,
      background: theme.screens.settings,
      child: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          return ListView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppScaffold.topPaddingOf(context),
              AppSpacing.md,
              MediaQuery.paddingOf(context).bottom + AppSpacing.xxl,
            ),
            children: [
              SectionLabel(l10n.settingsTranscription),
              SettingsCard(
                children: [
                  SettingsRow(
                    icon: AppIcons.globe,
                    title: l10n.settingsLanguage,
                    value: localeDisplayName(state.localeId),
                    chevron: true,
                    onTap: () => context.pushNamed(Routes.settingsLanguageName),
                  ),
                  _ModelRow(state: state),
                ],
              ),
              SectionLabel(l10n.settingsStorage),
              SettingsCard(
                children: [
                  SettingsToggle(
                    icon: AppIcons.icloud,
                    title: l10n.settingsBackup,
                    value: !state.backupExcluded,
                    onChanged: (included) =>
                        context.read<SettingsCubit>().setBackupExcluded(!included),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.sm, AppSpacing.sm, AppSpacing.sm, 0),
                child: Text(
                  l10n.settingsOffline,
                  style: AppType.footnote.copyWith(color: theme.textSecondary),
                ),
              ),
              SectionLabel(l10n.settingsAppearance),
              SettingsCard(
                children: [
                  SettingsRow(
                    key: _themeRow,
                    icon: AppIcons.moonFill,
                    title: l10n.settingsTheme,
                    value: _themeModeName(themeMode, l10n),
                    chevron: true,
                    onTap: () => _pickTheme(l10n),
                  ),
                  SettingsRow(
                    key: _languageRow,
                    icon: AppIcons.textformat,
                    title: l10n.settingsAppLanguage,
                    value: localeDisplayName(context.watch<AppLanguageCubit>().state),
                    chevron: true,
                    onTap: () => _pickAppLanguage(l10n),
                  ),
                ],
              ),
              SectionLabel(l10n.settingsAbout),
              SettingsCard(
                children: [
                  SettingsRow(
                    icon: AppIcons.docOnDoc,
                    title: l10n.settingsOpenSource,
                    value: _copied == _repoAddress ? l10n.copied : _repoAddress,
                    onTap: () => _copy(_repoAddress),
                  ),
                  SettingsRow(
                    icon: AppIcons.appleLogo,
                    title: l10n.settingsCreatedBy,
                    value: _copied == _authorHandle ? l10n.copied : _authorHandle,
                    onTap: () => _copy(_authorHandle),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
              Center(
                child: Text(
                  appVersion,
                  style: AppType.caption.copyWith(color: theme.textSecondary),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The model row's four faces: installed, downloadable, downloading, failed.
class _ModelRow extends StatelessWidget {
  const _ModelRow({required this.state});

  final SettingsState state;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;

    if (state.installing) {
      return SettingsRow(
        icon: AppIcons.waveform,
        title: l10n.settingsModel,
        // Its own bar, not the player's: an install has a progress, not a
        // playhead, and the two stopped sharing a shape when the player became
        // a wave.
        trailing: SizedBox(
          width: 80,
          height: 3,
          child: Stack(
            children: [
              Container(color: theme.hairline),
              FractionallySizedBox(
                widthFactor: (state.installProgress ?? 0).clamp(0.0, 1.0),
                child: Container(color: theme.accent),
              ),
            ],
          ),
        ),
      );
    }
    if (state.installFailed) {
      return SettingsRow(
        icon: AppIcons.waveform,
        title: l10n.settingsModel,
        value: l10n.settingsModelFailed,
        onTap: context.read<SettingsCubit>().install,
      );
    }
    if (state.modelInstalled) {
      return SettingsRow(
        icon: AppIcons.waveform,
        title: l10n.settingsModel,
        value: l10n.settingsModelInstalled,
      );
    }
    return SettingsRow(
      icon: AppIcons.waveform,
      title: l10n.settingsModel,
      value: l10n.settingsModelDownload,
      onTap: context.read<SettingsCubit>().install,
    );
  }
}
