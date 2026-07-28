import 'package:opentranscribe/core/utils/language_tags.dart';

/// Native display names for the languages the on-device engines ship, keyed by
/// language subtag. Data, not translation: a language picker names each
/// language in itself by convention, so these are deliberately not l10n keys.
/// Unknown tags fall back to themselves, which is honest if ugly.
const _languageNames = <String, String>{
  'ar': 'العربية',
  'da': 'Dansk',
  'de': 'Deutsch',
  'en': 'English',
  'es': 'Español',
  'fi': 'Suomi',
  'fr': 'Français',
  'he': 'עברית',
  'hi': 'हिन्दी',
  'id': 'Bahasa Indonesia',
  'it': 'Italiano',
  'ja': '日本語',
  'ko': '한국어',
  'nb': 'Norsk',
  'nl': 'Nederlands',
  'pl': 'Polski',
  'pt': 'Português',
  'ru': 'Русский',
  'sv': 'Svenska',
  'th': 'ไทย',
  'tr': 'Türkçe',
  'uk': 'Українська',
  'vi': 'Tiếng Việt',
  'yue': '粵語',
  'zh': '中文',
};

/// The flag emoji for a BCP-47 tag: its region subtag when present ("en-US" ->
/// US), else the language's home region. A globe when neither resolves, so a
/// picker row never renders a blank chip.
String localeFlag(String tag) {
  final parts = tag.split('-');
  final region = parts.length > 1
      ? parts.last.toUpperCase()
      : languageHomeRegion[parts.first.toLowerCase()];
  if (region == null || region.length != 2) return '\u{1F310}';
  // Two ASCII letters map to the two regional-indicator symbols that render as
  // a flag.
  return String.fromCharCodes(region.codeUnits.map((c) => 0x1F1E6 + (c - 0x41)));
}

/// A BCP-47 tag as a picker label: the language's native name plus the region
/// subtag when present ("English (US)", "Deutsch (DE)").
String localeDisplayName(String tag) {
  final parts = tag.split('-');
  final name = _languageNames[parts.first.toLowerCase()];
  if (name == null) return tag;
  final region = parts.length > 1 ? parts.last.toUpperCase() : null;
  return region == null ? name : '$name ($region)';
}
