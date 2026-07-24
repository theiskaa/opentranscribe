import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:opentranscribe/core/app/deps.dart';
import 'package:opentranscribe/core/models/engine_descriptor.dart';
import 'package:opentranscribe/core/state/settings_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/superellipse.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/app_scaffold.dart';
import 'package:opentranscribe/view/widgets/app_spinner.dart';
import 'package:opentranscribe/view/widgets/settings_kit.dart';

/// The transcription models: the on-device engines the build ships (one today,
/// Apple Speech), each a card with its logo, name, and install state. Kept its
/// own screen so the model's on-device nature - the whole privacy promise - gets
/// room to be stated, not squeezed into one settings row.
class ModelsScreen extends StatelessWidget {
  const ModelsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    final engines = Deps.i.engineDescriptors;

    return AppScaffold(
      background: theme.screens.settings,
      onBack: () => context.pop(),
      child: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          return SettingsList(
            children: [
              SectionInfo(l10n.settingsModelsInfo),
              for (final engine in engines) ...[
                _EngineCard(engine: engine, state: state),
                const SizedBox(height: AppSpacing.md),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// One engine as a card: its logo on a tile, its name, and a trailing state -
/// installed, downloadable (tap), downloading (progress), or failed (tap to
/// retry). The one engine today drives the shared install state on [SettingsCubit].
class _EngineCard extends StatelessWidget {
  const _EngineCard({required this.engine, required this.state});

  final EngineDescriptor engine;
  final SettingsState state;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final tokens = theme.settings;
    final l10n = AppLocalizations.of(context)!;

    return SettingsCard(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: SuperellipseDecoration(
                  borderRadius: tokens.iconTileRadius + 2,
                  color: tokens.iconTileBackground,
                ),
                child: AppIcon(engine.logo, size: 22, color: theme.text),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(engine.displayName, style: AppType.headline.copyWith(color: theme.text)),
                    const SizedBox(height: 2),
                    Text(
                      _stateLabel(l10n),
                      style: AppType.footnote.copyWith(color: theme.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _trailing(context),
            ],
          ),
        ),
      ],
    );
  }

  String _stateLabel(AppLocalizations l10n) {
    if (state.installing) return l10n.settingsModelDownload;
    if (state.installFailed) return l10n.settingsModelFailed;
    return state.modelInstalled ? l10n.settingsModelInstalled : l10n.settingsModelDownload;
  }

  Widget _trailing(BuildContext context) {
    final theme = context.theme;
    if (state.installing) {
      return SizedBox(
        width: 28,
        height: 28,
        child: Center(child: AppSpinner(size: 18, color: theme.textSecondary)),
      );
    }
    if (state.modelInstalled) {
      return AppIcon(AppIcons.checkmark, size: 16, color: theme.settings.toggleActive);
    }
    // Downloadable or failed: a tappable download glyph that (re)starts the
    // install. The row's whole tap target would be nicer, but the card holds
    // more than a single action, so the affordance is the glyph.
    return _DownloadButton(onTap: () => context.read<SettingsCubit>().install());
  }
}

class _DownloadButton extends StatelessWidget {
  const _DownloadButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: AppIcon(AppIcons.icloud, size: 22, color: theme.accent),
      ),
    );
  }
}
