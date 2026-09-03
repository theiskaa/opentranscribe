import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/app/deps.dart';
import 'package:opentranscribe/core/models/exporter_descriptor.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/superellipse.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/layouts/onboarding/components/onboarding_page.dart';
import 'package:opentranscribe/view/layouts/onboarding/components/onboarding_row.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/export_format_row.dart';
import 'package:opentranscribe/view/widgets/settings_kit.dart';

/// The third page: yours, in any shape. The three formats as tiles, the first
/// picked, and the sealed backup beneath them with its passphrase. Still, like
/// the reflections page.
class OnboardingShape extends StatelessWidget {
  const OnboardingShape({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return OnboardingPage(
      scene: const _ShapeScene(),
      title: l10n.onboardingShapeTitle,
      body: l10n.onboardingShapeBody,
    );
  }
}

class _ShapeScene extends StatelessWidget {
  const _ShapeScene();

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    final descriptors = Deps.i.exporterDescriptors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Equal-height tiles under an unbounded scroll height: the row itself
        // has no height to stretch to, so it is sized to its tallest tile.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, descriptor) in descriptors.indexed) ...[
                if (i > 0) const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _FormatTile(descriptor: descriptor, picked: i == 0),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SettingsCard(
          children: [
            OnboardingRow(
              leading: AppIcon(AppIcons.lock, size: 16, color: theme.textSecondary),
              name: l10n.settingsBackup,
              note: l10n.onboardingBackupLine,
              trailing: const _Passphrase(),
            ),
          ],
        ),
      ],
    );
  }
}

/// One format as a tile: its mark, its name, and a short note. The [picked]
/// tile wears an ink border, the mock's signal for the chosen one; the app's
/// own rows say it with weight and a check, which a tile has no row for.
class _FormatTile extends StatelessWidget {
  const _FormatTile({required this.descriptor, required this.picked});

  final ExporterDescriptor descriptor;
  final bool picked;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    final tokens = theme.settings;
    // The tile's own short words: the format names and notes the backup screen
    // uses run to two lines at this width.
    final (name, note) = switch (descriptor.format) {
      ExportFormat.markdown => (l10n.exportFormatMarkdown, l10n.onboardingShapeMarkdownNote),
      ExportFormat.obsidian => (l10n.onboardingShapeObsidianName, l10n.onboardingShapeObsidianNote),
      ExportFormat.web => (l10n.exportFormatWeb, l10n.onboardingShapeWebNote),
    };
    return DecoratedBox(
      decoration: SuperellipseDecoration(
        borderRadius: tokens.cardRadius,
        color: tokens.cardBackground,
        border: BorderSide(color: picked ? theme.text : tokens.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExporterLogo(descriptor),
            const SizedBox(height: AppSpacing.lg),
            Text(
              name,
              style: AppType.subhead.copyWith(color: theme.text, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              note,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.footnote.copyWith(color: theme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// A sealed passphrase: six filled dots.
class _Passphrase extends StatelessWidget {
  const _Passphrase();

  static const _dots = 6;
  static const _dot = 7.0;
  static const _gap = 5.0;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < _dots; i++) ...[
          if (i > 0) const SizedBox(width: _gap),
          Container(
            width: _dot,
            height: _dot,
            decoration: BoxDecoration(shape: BoxShape.circle, color: theme.text),
          ),
        ],
      ],
    );
  }
}
