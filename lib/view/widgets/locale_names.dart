import 'package:opentranscribe/core/utils/language_tags.dart';

/// Native display names for every language an on-device engine ships, keyed
/// by language subtag. Data, not translation: a language picker names each
/// language in itself by convention, so these are deliberately not l10n keys.
/// Unknown tags fall back to themselves, which is honest if ugly.
const _languageNames = <String, String>{
  'af': 'Afrikaans',
  'am': 'አማርኛ',
  'ar': 'العربية',
  'as': 'অসমীয়া',
  'az': 'Azərbaycanca',
  'ba': 'Башҡортса',
  'be': 'Беларуская',
  'bg': 'Български',
  'bn': 'বাংলা',
  'bo': 'བོད་སྐད་',
  'br': 'Brezhoneg',
  'bs': 'Bosanski',
  'ca': 'Català',
  'cs': 'Čeština',
  'cy': 'Cymraeg',
  'da': 'Dansk',
  'de': 'Deutsch',
  'el': 'Ελληνικά',
  'en': 'English',
  'es': 'Español',
  'et': 'Eesti',
  'eu': 'Euskara',
  'fa': 'فارسی',
  'fi': 'Suomi',
  'fo': 'Føroyskt',
  'fr': 'Français',
  'gl': 'Galego',
  'gu': 'ગુજરાતી',
  'ha': 'Hausa',
  'haw': 'ʻŌlelo Hawaiʻi',
  'he': 'עברית',
  'hi': 'हिन्दी',
  'hr': 'Hrvatski',
  'ht': 'Kreyòl ayisyen',
  'hu': 'Magyar',
  'hy': 'Հայերեն',
  'id': 'Bahasa Indonesia',
  'is': 'Íslenska',
  'it': 'Italiano',
  'ja': '日本語',
  'jv': 'Basa Jawa',
  'ka': 'ქართული',
  'kk': 'Қазақша',
  'km': 'ខ្មែរ',
  'kn': 'ಕನ್ನಡ',
  'ko': '한국어',
  'la': 'Latina',
  'lb': 'Lëtzebuergesch',
  'ln': 'Lingála',
  'lo': 'ລາວ',
  'lt': 'Lietuvių',
  'lv': 'Latviešu',
  'mg': 'Malagasy',
  'mi': 'Māori',
  'mk': 'Македонски',
  'ml': 'മലയാളം',
  'mn': 'Монгол',
  'mr': 'मराठी',
  'ms': 'Bahasa Melayu',
  'mt': 'Malti',
  'my': 'မြန်မာ',
  'nb': 'Norsk',
  'ne': 'नेपाली',
  'nl': 'Nederlands',
  'nn': 'Nynorsk',
  'oc': 'Occitan',
  'pa': 'ਪੰਜਾਬੀ',
  'pl': 'Polski',
  'ps': 'پښتو',
  'pt': 'Português',
  'ro': 'Română',
  'ru': 'Русский',
  'sa': 'संस्कृतम्',
  'sd': 'سنڌي',
  'si': 'සිංහල',
  'sk': 'Slovenčina',
  'sl': 'Slovenščina',
  'sn': 'chiShona',
  'so': 'Soomaali',
  'sq': 'Shqip',
  'sr': 'Српски',
  'su': 'Basa Sunda',
  'sv': 'Svenska',
  'sw': 'Kiswahili',
  'ta': 'தமிழ்',
  'te': 'తెలుగు',
  'tg': 'Тоҷикӣ',
  'th': 'ไทย',
  'tk': 'Türkmençe',
  'tl': 'Tagalog',
  'tr': 'Türkçe',
  'tt': 'Татарча',
  'uk': 'Українська',
  'ur': 'اردو',
  'uz': 'Oʻzbekcha',
  'vi': 'Tiếng Việt',
  'yi': 'ייִדיש',
  'yo': 'Yorùbá',
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
