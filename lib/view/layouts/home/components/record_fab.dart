import 'package:flutter/widgets.dart';
import 'package:liquid/liquid.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/utils/platform_caps.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';

/// The floating record button: a persistent, obvious way to start a new entry,
/// beside the quieter pull-to-record gesture. On iOS 26 it is the native Liquid
/// Glass circle so it matches the rest of the app's glass chrome; everywhere
/// else it is a surface disc with the brand waveform in ink - the same
/// restrained tone in every theme (never the accent hue, never stark white). The
/// tap's haptic and navigation belong to [onTap], so this stays
/// presentation-only.
class RecordFab extends StatelessWidget {
  const RecordFab({required this.onTap, super.key});

  final VoidCallback onTap;

  static const double size = 58;
  static const double _iconSize = 26;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    if (PlatformCaps.nativeGlass) {
      // The native side draws the glyph from the SF Symbol NAME - the vendored
      // icon font never reaches it. isDark keeps the glass in step with the
      // chosen theme family, not just the system appearance.
      return LiquidIconButton(
        icon: AppIcons.sfSymbolName(AppIcons.waveform),
        iconPointSize: _iconSize,
        tintColor: theme.text,
        isDark: theme.brightness == Brightness.dark,
        onPressed: onTap,
        size: size,
      );
    }

    return Touchable(
      onTap: onTap,
      pressedScale: theme.motion.pressScale,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: theme.surface,
          shape: BoxShape.circle,
          border: Border.all(color: theme.surfaceBorder),
          boxShadow: [
            BoxShadow(
              color: theme.shadow.withValues(alpha: 0.14),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: AppIcon(AppIcons.waveform, size: _iconSize, color: theme.text),
        ),
      ),
    );
  }
}
