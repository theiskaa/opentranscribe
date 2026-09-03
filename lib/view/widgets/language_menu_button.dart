import 'package:flutter/widgets.dart';

import 'package:opentranscribe/core/theming/app_icons.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/app_menu.dart';
import 'package:opentranscribe/view/widgets/locale_names.dart';

/// The adaptive language menu behind a globe bar button: a native UIMenu on
/// glass, the app's anchored menu elsewhere, every usable language listed with
/// the current one checked. What picking MEANS belongs to the caller (the
/// recorder re-languages its session, the models screen sets the default), so
/// the same control reads the same everywhere while acting locally.
class LanguageMenuButton extends StatelessWidget {
  const LanguageMenuButton({
    required this.current,
    required this.tags,
    required this.onPick,
    this.color,
    super.key,
  });

  final String current;
  final List<String> tags;
  final ValueChanged<String> onPick;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();
    return AppMenuButton(
      icon: AppIcons.globe,
      color: color,
      semanticLabel: AppLocalizations.of(context)!.languageMenuButton,
      items: [
        for (final tag in tags)
          AppMenuItem(
            // The tag IS the identity: an open menu answering after the list
            // rebuilt underneath must still apply the language it displayed.
            id: tag,
            label: '${localeFlag(tag)}  ${localeDisplayName(tag)}',
            selected: tag == current,
          ),
      ],
      onSelectedId: onPick,
    );
  }
}
