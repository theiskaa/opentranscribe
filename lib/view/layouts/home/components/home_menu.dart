import 'dart:async';

import 'package:flutter/foundation.dart' show Uint8List, kDebugMode;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:opentranscribe/core/app/deps.dart';
import 'package:opentranscribe/core/routes/routes.dart';
import 'package:opentranscribe/core/state/app_language_cubit.dart';
import 'package:opentranscribe/core/state/settings_cubit.dart';
import 'package:opentranscribe/core/theming/app_icons.dart';
import 'package:opentranscribe/core/utils/url.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/app_dropdown.dart';
import 'package:opentranscribe/view/widgets/app_menu.dart';
import 'package:opentranscribe/view/widgets/locale_names.dart';

/// The one door out of home. It replaces the settings screen: every setting
/// that used to live there is a row here (or a submenu, for the two language
/// pickers, exactly like Transcribe-in on the entry screen), so leaving home is
/// never more than one tap plus a choice. The GitHub row is the only thing that
/// points outward; see the one rule in CLAUDE.md.
class HomeMenu extends StatefulWidget {
  const HomeMenu({this.color, super.key});

  final Color? color;

  @override
  State<HomeMenu> createState() => _HomeMenuState();
}

class _HomeMenuState extends State<HomeMenu> {
  /// The public repository. A link, not a socket the app opens; the OS browser
  /// does, for a URL that carries no user data.
  static const _repoUrl = 'github.com/theiskaa/opentranscribe';

  /// Read from the bundle so it is never out of step with the pubspec. Null
  /// until the async read lands; the row shows the bare label until then.
  String? _version;

  /// The GitHub mark's PNG bytes, loaded once. UIMenu has no SF Symbol for a
  /// brand logo, so the image travels to the native menu as bytes rather than
  /// by an asset-catalog name (which the plugin cannot reliably resolve). Null
  /// until the read lands; the Source row shows no mark until then.
  Uint8List? _githubBytes;

  /// The menu button, which the fallback language dropdowns anchor to (the menu
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

  /// The transcription languages the default picker offers: the settings list
  /// when it has loaded, else the service default alone, so a cold-start menu
  /// still names one language rather than showing an empty submenu.
  List<String> _defaultTags(SettingsState settings) {
    final tags = settings.selectableLanguageTags();
    if (tags.isNotEmpty) return tags;
    final fallback = Deps.i.transcriptionService.localeId;
    return fallback.isEmpty ? const [] : [fallback];
  }

  /// The transcription default in effect: the settings value once loaded, else
  /// the service default, so a cold-start menu still checks one language.
  String _currentDefault(SettingsState settings) =>
      settings.localeId.isNotEmpty ? settings.localeId : Deps.i.transcriptionService.localeId;

  /// The app-language codes, one per supported UI locale.
  List<String> get _appCodes => [for (final l in AppLocalizations.supportedLocales) l.languageCode];

  void _pickDefaultLanguage(SettingsState settings) async {
    final tags = _defaultTags(settings);
    if (tags.isEmpty) return;
    final index = await _openDropdown(tags, _currentDefault(settings));
    if (index != null && mounted) {
      unawaited(context.read<SettingsCubit>().setLocale(tags[index]));
    }
  }

  void _pickAppLanguage(String current) async {
    final codes = _appCodes;
    final index = await _openDropdown(codes, current);
    if (index != null && mounted) {
      unawaited(context.read<AppLanguageCubit>().setLanguage(codes[index]));
    }
  }

  /// The fallback picker (non-native platforms): the app's anchored dropdown out
  /// of the menu button. On native glass the submenu carries the languages, and
  /// these are never called.
  Future<int?> _openDropdown(List<String> tags, String current) {
    final box = _anchor.currentContext?.findRenderObject();
    final screen = MediaQuery.sizeOf(context);
    final anchor = box is RenderBox && box.attached
        ? box.localToGlobal(Offset.zero) & box.size
        : Rect.fromLTWH(screen.width - 60, MediaQuery.paddingOf(context).top, 44, 44);
    return showAppDropdown(
      context,
      anchor: anchor,
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
    final settings = context.watch<SettingsCubit>().state;
    final appLang = context.watch<AppLanguageCubit>().state;

    final currentDefault = _currentDefault(settings);
    final sourceLabel = _version == null ? l10n.menuSourceCode : '$_version';

    // Grouped, not just listed: Search, then the transcription group (Models,
    // Transcription), the app group (Appearance, Language), then Source. Native
    // menus draw a real divider between groups; the fallback keeps the order.
    // The two language pickers close different groups on purpose, so they never
    // sit right under each other. Each parent's position is captured as it is
    // added: parents are the only id-less items, so on the fallback they alone
    // reach onSelected(index).
    final items = <AppMenuItem>[
      AppMenuItem(id: 'act:search', label: l10n.navSearch, icon: AppIcons.magnifyingglass),
      const AppMenuItem.divider(),
      AppMenuItem(id: 'act:models', label: l10n.settingsModels, icon: AppIcons.waveform),
    ];
    final defaultLangIndex = items.length;
    items.add(
      AppMenuItem(
        label: l10n.menuTranscriptionLanguage,
        icon: AppIcons.globe,
        children: [
          for (final tag in _defaultTags(settings))
            AppMenuItem(
              id: 'tx:$tag',
              label: '${localeFlag(tag)}  ${localeDisplayName(tag)}',
              selected: tag == currentDefault,
            ),
        ],
      ),
    );
    items.add(const AppMenuItem.divider());
    items.add(
      AppMenuItem(id: 'act:appearance', label: l10n.settingsAppearance, icon: AppIcons.moonFill),
    );
    final appLangIndex = items.length;
    items.add(
      AppMenuItem(
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
    );
    items.add(const AppMenuItem.divider());
    items.add(AppMenuItem(id: 'act:source', label: sourceLabel, iconBytes: _githubBytes));
    if (kDebugMode) {
      items.add(const AppMenuItem.divider());
      items.add(
        const AppMenuItem(id: 'act:gallery', label: 'Widget gallery', icon: AppIcons.waveform),
      );
    }

    return AppMenuButton(
      key: _anchor,
      icon: AppIcons.ellipsis,
      color: widget.color,
      items: items,
      // Fires only for the two parents on the fallback (every leaf carries an
      // id, so it answers through onSelectedId instead).
      onSelected: (index) {
        if (index == defaultLangIndex) {
          _pickDefaultLanguage(settings);
        } else if (index == appLangIndex) {
          _pickAppLanguage(appLang);
        }
      },
      onSelectedId: (id) {
        if (id.startsWith('tx:')) {
          unawaited(context.read<SettingsCubit>().setLocale(id.substring(3)));
        } else if (id.startsWith('app:')) {
          unawaited(context.read<AppLanguageCubit>().setLanguage(id.substring(4)));
        } else {
          switch (id) {
            case 'act:models':
              context.pushNamed(Routes.settingsModelsName);
            case 'act:appearance':
              context.pushNamed(Routes.settingsAppearanceName);
            case 'act:gallery':
              context.pushNamed(Routes.galleryName);
            case 'act:source':
              unawaited(openLink(_repoUrl));
            case 'act:search':
              // No search screen yet; present but inert.
              break;
          }
        }
      },
    );
  }
}
