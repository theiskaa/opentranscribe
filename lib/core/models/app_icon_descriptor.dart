import 'package:flutter/widgets.dart';

import 'package:opentranscribe/l10n/generated/app_localizations.dart';

/// Presentation facts about one home screen icon the build ships. Built at
/// the composition root, the one place allowed to name an icon asset;
/// surfaces render descriptors without knowing what is behind them.
@immutable
final class AppIconDescriptor {
  const AppIconDescriptor({
    required this.id,
    required this.iconName,
    required this.preview,
    required this.name,
  });

  final String id;

  /// The alternate icon's asset catalog name; null is the primary icon.
  final String? iconName;

  /// The bundled preview image the picker shows.
  final String preview;

  /// A function because descriptors are built before any locale is current.
  final String Function(AppLocalizations) name;
}
