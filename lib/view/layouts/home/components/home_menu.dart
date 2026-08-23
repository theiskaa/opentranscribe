import 'dart:async';

import 'package:flutter/foundation.dart' show Uint8List, kDebugMode;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:opentranscribe/core/routes/routes.dart';
import 'package:opentranscribe/core/state/app_language_cubit.dart';
import 'package:opentranscribe/core/theming/app_icons.dart';
import 'package:opentranscribe/core/utils/url.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/layouts/home/components/retranscribe_sheet.dart';
import 'package:opentranscribe/view/widgets/app_dropdown.dart';
import 'package:opentranscribe/view/widgets/app_menu.dart';
import 'package:opentranscribe/view/widgets/locale_names.dart';

/// The one door out of home. It replaces the settings screen: every setting
/// that used to live there is a row here (or a submenu, for the app-language
/// picker), so leaving home is never more than one tap plus a choice. The
/// transcription default lives on the Transcription screen, not here. The
/// GitHub row is the only thing that points outward; see the one rule in
/// CLAUDE.md.
class HomeMenu extends StatefulWidget {
  const HomeMenu({this.color, super.key});

  final Color? color;

  @override
  State<HomeMenu> createState() => _HomeMenuState();
}

class _HomeMenuState extends State<HomeMenu> {
  /// Read from the bundle so it is never out of step with the pubspec. Null
  /// until the async read lands; the row shows the bare label until then.
  String? _version;

  /// The GitHub mark's PNG bytes, loaded once. UIMenu has no SF Symbol for a
  /// brand logo, so the image travels to the native menu as bytes rather than
  /// by an asset-catalog name (which the plugin cannot reliably resolve). Null
  /// until the read lands; the Source row shows no mark until then.
  Uint8List? _githubBytes;

  /// The menu button, which the fallback language dropdown anchors to (the menu
  /// that offered the choice grew from the same spot).
  final GlobalKey _anchor = GlobalKey();

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = 'v${info.version} (${info.buildNumber})');
    });
    unawaited(_loadGithubMark());
  }

  /// Reads the GitHub mark once. Guarded: if the asset is unavailable (e.g. a
  /// hot restart before a full rebuild has bundled it), the Source row just
  /// shows no mark rather than throwing.
  Future<void> _loadGithubMark() async {
    try {
      final data = await rootBundle.load('assets/brand/github.png');
      if (mounted) setState(() => _githubBytes = data.buffer.asUint8List());
    } catch (_) {
      // No mark until the asset is bundled; nothing else to do.
    }
  }

  /// The app-language codes, one per supported UI locale.
  List<String> get _appCodes => [for (final l in AppLocalizations.supportedLocales) l.languageCode];

  void _pickAppLanguage(String current) async {
    final codes = _appCodes;
    final index = await _openDropdown(codes, current);
    if (index != null && mounted) {
      unawaited(context.read<AppLanguageCubit>().setLanguage(codes[index]));
    }
  }

  /// The fallback picker (non-native platforms): the app's anchored dropdown out
  /// of the menu button. On native glass the submenu carries the languages, and
  /// this is never called.
  Future<int?> _openDropdown(List<String> tags, String current) {
    return showAppDropdown(
      context,
      anchor: dropdownAnchorRect(_anchor, context),
      items: [
        for (final tag in tags)
          AppDropdownItem(
            label: localeDisplayName(tag),
            flag: localeFlag(tag),
            selected: tag == current,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appLang = context.watch<AppLanguageCubit>().state;
    final sourceLabel = _version ?? l10n.menuSourceCode;

    final items = <AppMenuItem>[
      AppMenuItem(id: 'act:models', label: l10n.settingsModels, icon: AppIcons.waveform),
      AppMenuItem(
        id: 'act:retranscribe',
        label: l10n.retranscribeAllTitle,
        icon: AppIcons.arrowCounterclockwise,
      ),
      AppMenuItem(id: 'act:reflections', label: l10n.reflectionsTitle, icon: AppIcons.calendar),
      AppMenuItem(id: 'act:notifications', label: l10n.settingsNotifications, icon: AppIcons.bell),
      AppMenuItem(id: 'act:cache', label: l10n.settingsCache, icon: AppIcons.internaldrive),
      AppMenuItem(id: 'act:backup', label: l10n.settingsBackup, icon: AppIcons.squareAndArrowUp),
      const AppMenuItem.divider(),
      AppMenuItem(id: 'act:appearance', label: l10n.settingsAppearance, icon: AppIcons.moonFill),
      AppMenuItem(
        id: 'act:applang',
        label: l10n.settingsAppLanguage,
        icon: AppIcons.textformat,
        children: [
          for (final locale in AppLocalizations.supportedLocales)
            AppMenuItem(
              id: 'app:${locale.languageCode}',
              label:
                  '${localeFlag(locale.toLanguageTag())}  '
                  '${localeDisplayName(locale.toLanguageTag())}',
              selected: locale.languageCode == appLang,
            ),
        ],
      ),
      const AppMenuItem.divider(),
      AppMenuItem(id: 'act:support', label: l10n.settingsSupport, icon: AppIcons.heart),
      AppMenuItem(id: 'act:source', label: sourceLabel, iconBytes: _githubBytes),
      if (kDebugMode) ...[
        const AppMenuItem.divider(),
        const AppMenuItem(id: 'act:gallery', label: 'Widget gallery', icon: AppIcons.waveform),
      ],
    ];

    return AppMenuButton(
      key: _anchor,
      icon: AppIcons.ellipsis,
      color: widget.color,
      items: items,
      onSelectedId: (id) {
        if (id.startsWith('app:')) {
          unawaited(context.read<AppLanguageCubit>().setLanguage(id.substring(4)));
          return;
        }
        switch (id) {
          case 'act:applang':
            _pickAppLanguage(appLang);
          case 'act:models':
            context.pushNamed(Routes.settingsModelsName);
          case 'act:retranscribe':
            unawaited(showRetranscribeSheet(context));
          case 'act:appearance':
            context.pushNamed(Routes.settingsAppearanceName);
          case 'act:reflections':
            context.pushNamed(Routes.reflectionsName);
          case 'act:cache':
            context.pushNamed(Routes.settingsCacheName);
          case 'act:backup':
            context.pushNamed(Routes.settingsBackupName);
          case 'act:notifications':
            context.pushNamed(Routes.settingsNotificationsName);
          case 'act:support':
            context.pushNamed(Routes.settingsSupportName);
          case 'act:gallery':
            context.pushNamed(Routes.galleryName);
          case 'act:source':
            unawaited(openLink(kRepoUrl));
        }
      },
    );
  }
}
