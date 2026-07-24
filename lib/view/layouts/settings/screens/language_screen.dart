import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:opentranscribe/core/state/settings_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/app_scaffold.dart';
import 'package:opentranscribe/view/widgets/locale_names.dart';
import 'package:opentranscribe/view/widgets/settings_kit.dart';

/// The transcription-language picker. The current choice may not literally
/// appear in the engine's list (a device default resolving to a near variant,
/// or an unsupported language kept honestly); it then renders as its own row
/// with its availability, never silently swapped for something else.
class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;

    return AppScaffold(
      // Bare frosted bar: the rows say what this is.
      background: theme.screens.settings,
      onBack: () => context.pop(),
      child: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          final current = state.localeId;
          final listed = state.supportedLocales.contains(current);
          final unavailable = state.availability != null && !state.availability!.isAvailable;

          return SettingsList(
            children: [
              SectionInfo(l10n.settingsLanguageInfo),
              SettingsCard(
                children: [
                  if (!listed)
                    SelectableRow(
                      label: localeDisplayName(current),
                      flag: localeFlag(current),
                      selected: true,
                      dimmed: unavailable,
                      onTap: null,
                    ),
                  for (final tag in state.supportedLocales)
                    SelectableRow(
                      label: localeDisplayName(tag),
                      flag: localeFlag(tag),
                      selected: listed && tag == current,
                      onTap: () {
                        context.read<SettingsCubit>().setLocale(tag);
                        context.pop();
                      },
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
