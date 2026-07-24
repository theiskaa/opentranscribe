import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:opentranscribe/core/state/app_language_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/app_scaffold.dart';
import 'package:opentranscribe/view/widgets/locale_names.dart';
import 'package:opentranscribe/view/widgets/settings_kit.dart';

/// The app-language (UI locale) picker: a pushed screen with one selectable row
/// per supported locale, the current one checked. Picking re-locales the app in
/// place; the check moves and the screen stays, matching the transcription
/// picker rather than a dropdown.
class AppLanguageScreen extends StatelessWidget {
  const AppLanguageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return AppScaffold(
      // Bare frosted bar: the rows say what this is.
      background: theme.screens.settings,
      onBack: () => context.pop(),
      child: BlocBuilder<AppLanguageCubit, String>(
        builder: (context, current) {
          final l10n = AppLocalizations.of(context)!;
          const locales = AppLocalizations.supportedLocales;
          return SettingsList(
            children: [
              SectionInfo(l10n.settingsAppLanguageInfo),
              SettingsCard(
                children: [
                  for (final locale in locales)
                    SelectableRow(
                      label: localeDisplayName(locale.toLanguageTag()),
                      flag: localeFlag(locale.toLanguageTag()),
                      selected: locale.languageCode == current,
                      onTap: locale.languageCode == current
                          ? null
                          : () => context.read<AppLanguageCubit>().setLanguage(locale.languageCode),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
