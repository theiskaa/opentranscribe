import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/settings_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/superellipse.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/locale_flag.dart';
import 'package:opentranscribe/view/widgets/locale_names.dart';
import 'package:opentranscribe/view/widgets/melt_stack.dart';
import 'package:opentranscribe/view/widgets/model_failure_line.dart';
import 'package:opentranscribe/view/widgets/rolling_text.dart';
import 'package:opentranscribe/view/widgets/settings_kit.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';

/// The default language as the screen's answer to "what happens when I hit
/// record": big flag, name, and an honest status line. The whole card taps
/// into the language sheet.
class SpeakingHero extends StatelessWidget {
  const SpeakingHero({required this.state, required this.onTap, super.key});

  final SettingsState state;
  final VoidCallback onTap;

  /// The list tile grown to headline scale; the flag grows with it.
  static const double _tileSize = 52;
  static const double _flagSize = 26;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final tokens = theme.settings;
    final l10n = AppLocalizations.of(context)!;
    final row = state.defaultLanguage;
    final tag = row?.tag ?? state.localeId;
    final crossfade = context.reduceMotion ? Duration.zero : theme.motion.crossfade;
    final statusLine = row == null || row.installing ? null : _statusLine(l10n, row);
    return Touchable(
      onTap: onTap,
      haptic: true,
      child: SettingsCard(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            // A chip tap swaps the whole card to another language; the old
            // face melts into the new instead of teleporting.
            child: AnimatedSwitcher(
              duration: crossfade,
              layoutBuilder: meltStack,
              child: Row(
                key: ValueKey(tag),
                children: [
                  Container(
                    width: _tileSize,
                    height: _tileSize,
                    alignment: Alignment.center,
                    decoration: SuperellipseDecoration(
                      borderRadius: tokens.iconTileRadius + 4,
                      color: tokens.iconTileBackground,
                    ),
                    child: LocaleFlag(localeFlag(tag), size: _flagSize),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localeDisplayName(tag),
                          overflow: TextOverflow.ellipsis,
                          style: AppType.headline.copyWith(color: theme.text),
                        ),
                        const SizedBox(height: 3),
                        // The status slot is ALWAYS two footnote lines tall
                        // (the invisible ruler below holds it): statuses run
                        // one line on one engine and two on the other, and a
                        // slot that breathed with them would shove the name
                        // and tile around the card on every switch. Only the
                        // words change, crossfading in place.
                        Stack(
                          children: [
                            const Opacity(opacity: 0, child: Text('\n', style: AppType.footnote)),
                            AnimatedSwitcher(
                              duration: crossfade,
                              layoutBuilder: meltStack,
                              child: row == null
                                  ? const SizedBox.shrink()
                                  : row.installing
                                  ? _DownloadingLine(fraction: row.installFraction!)
                                  : Text(
                                      statusLine!,
                                      key: ValueKey(statusLine),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppType.footnote.copyWith(color: theme.textSecondary),
                                    ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppIcon(AppIcons.chevronForward, size: 15, color: theme.textSecondary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The honest one-liner under the name: whatever stands in the way, else
  /// ready. A running download takes [_DownloadingLine] instead.
  String _statusLine(AppLocalizations l10n, LanguageModelState row) =>
      modelTroubleLine(l10n, row, managesModels: state.managesModels) ??
      l10n.transcriptionHeroReady;
}

/// "Downloading · 42%", the percent rolling odometer-style as fractions land,
/// so the hero reads the default language's own download without a ring.
class _DownloadingLine extends StatelessWidget {
  const _DownloadingLine({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final l10n = AppLocalizations.of(context)!;
    final style = AppType.footnote.copyWith(color: theme.textSecondary);
    final percent = (fraction.clamp(0.0, 1.0) * 100).round();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${l10n.transcriptionDownloading} · ', style: style),
        RollingText(
          text: '$percent%',
          style: AppType.digits(AppType.footnote).copyWith(color: theme.textSecondary),
          // Quiet secondary text: every changed digit moves together.
          stagger: Duration.zero,
        ),
      ],
    );
  }
}
