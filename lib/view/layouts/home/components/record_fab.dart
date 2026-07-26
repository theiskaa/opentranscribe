import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/view/widgets/app_icon.dart';
import 'package:opentranscribe/view/widgets/touchable.dart';

/// The floating record button: a persistent, obvious way to start a new entry,
/// beside the quieter pull-to-record gesture. A surface disc with the brand
/// waveform in ink - the same restrained tone in every theme (never the accent
/// hue, never stark white), so it reads as one consistent control. The tap's
/// haptic and navigation belong to [onTap] (the recorder-open path), so this
/// stays presentation-only.
class RecordFab extends StatelessWidget {
  const RecordFab({required this.onTap, super.key});

  final VoidCallback onTap;

  static const double size = 58;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
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
        child: Center(child: AppIcon(AppIcons.waveform, size: 26, color: theme.text)),
      ),
    );
  }
}
