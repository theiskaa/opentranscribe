import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/settings_cubit.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
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
/// record": big bare flag, name, and an honest status line naming the engine
/// that answers. The whole card taps into whatever the screen wires: the
/// library, or a broken default's story.
class SpeakingHero extends StatelessWidget {
  const SpeakingHero({
    required this.state,
    required this.engineName,
    required this.onTap,
    super.key,
  });

  final SettingsState state;

  /// Display name of the engine the state's readiness describes; null until
  /// known, and the ready line waits for it.
  final String? engineName;

  final VoidCallback onTap;

  /// Bare flag in a fixed slot, so the name column stays still across languages.
  static const double _flagSize = 34;
  static const double _flagSlot = 44;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
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
                  SizedBox(
                    width: _flagSlot,
                    child: LocaleFlag(localeFlag(tag), size: _flagSize),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localeDisplayName(tag),
                          // One line always: a wrapping name would break the
                          // constant card geometry the status ruler holds.
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.headline.copyWith(color: theme.text),
                        ),
                        // 3, off the scale: xs floats the status too far off
                        // the name it qualifies.
                        const SizedBox(height: 3),
                        // One footnote line always, held by the invisible ruler: a slot
                        // that breathed with the words would shove the name and flag
                        // on every switch.
                        Stack(
                          children: [
                            const Opacity(opacity: 0, child: Text(' ', style: AppType.footnote)),
                            AnimatedSwitcher(
                              duration: crossfade,
                              layoutBuilder: meltStack,
                              child: row == null
                                  ? const SizedBox.shrink()
                                  : row.installing
                                  ? _DownloadingLine(fraction: row.installFraction!)
                                  : statusLine == null
                                  ? const SizedBox.shrink()
                                  : Text(
                                      statusLine,
                                      key: ValueKey(statusLine),
                                      maxLines: 1,
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

  /// Whatever stands in the way, else ready naming the engine; a running
  /// download takes [_DownloadingLine] instead.
  String? _statusLine(AppLocalizations l10n, LanguageModelState row) =>
      modelTroubleLine(l10n, row, managesModels: state.managesModels) ??
      (engineName == null ? null : l10n.transcriptionHeroReady(engineName!));
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
