import 'package:flutter/widgets.dart';
import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/view/widgets/duo_style.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';

import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/glass_fab.dart';

/// The floating record button: a persistent, obvious way to start a new entry,
/// beside the quieter pull-to-record gesture. The brand waveform on the shared
/// floating disc.
class RecordFab extends StatelessWidget {
  const RecordFab({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (duoInnerOf(context)) {
      final theme = context.theme;
      return Semantics(
        button: true,
        label: AppLocalizations.of(context)!.recordButton,
        onTap: onTap,
        excludeSemantics: true,
        child: Touchable(
          onTap: onTap,
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: Container(
              width: AppDuo.barItem,
              height: AppDuo.barItem,
              decoration: BoxDecoration(color: theme.accent, shape: BoxShape.circle),
              child: Center(
                child: AppIcon(AppIcons.waveform, size: AppDuo.barGlyph, color: theme.onAccent),
              ),
            ),
          ),
        ),
      );
    }
    return GlassFab(
      icon: AppIcons.waveform,
      semanticLabel: AppLocalizations.of(context)!.recordButton,
      onTap: onTap,
    );
  }
}
