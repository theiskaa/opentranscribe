import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:opentranscribe/core/state/theme_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/view/widgets/wave_glyph.dart';

/// The settings footer, reeed's shape: the app's mark over its version and build
/// number, read from the bundle at runtime so it is never out of step with the
/// pubspec. The mark is the app's own - the pull-to-record wave, quiet here.
class VersionFooter extends StatefulWidget {
  const VersionFooter({super.key});

  @override
  State<VersionFooter> createState() => _VersionFooterState();
}

class _VersionFooterState extends State<VersionFooter> {
  String? _version;

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = 'v${info.version} (${info.buildNumber})');
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Column(
      children: [
        WaveGlyph(size: 32, color: theme.textSecondary.withValues(alpha: 0.6)),
        const SizedBox(height: AppSpacing.sm),
        // Reserve the line so the footer does not jump when the async read lands.
        SizedBox(
          height: AppType.caption.fontSize! * 1.4,
          child: Text(
            _version ?? '',
            style: AppType.digits(AppType.caption).copyWith(color: theme.textSecondary),
          ),
        ),
      ],
    );
  }
}
