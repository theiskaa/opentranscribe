/// BCP-47 tag logic shared by every language surface: resolving a derived tag
/// to one the engine supports, and the one ordering all pickers agree on.
/// Data and string work only; no engine is named here.
library;

/// A representative home region per language: the variant a bare language
/// resolves to, and the one listed first among its siblings. A language is not
/// a country, so this is convention, not fact (pt reads BR, the variant
/// engines actually ship).
const languageHomeRegion = <String, String>{
  'af': 'ZA',
  'am': 'ET',
  'ar': 'SA',
  'as': 'IN',
  'az': 'AZ',
  'ba': 'RU',
  'be': 'BY',
  'bg': 'BG',
  'bn': 'BD',
  'bo': 'CN',
  'br': 'FR',
  'bs': 'BA',
  'ca': 'ES',
  'cs': 'CZ',
  'cy': 'GB',
  'da': 'DK',
  'de': 'DE',
  'el': 'GR',
  'en': 'US',
  'es': 'ES',
  'et': 'EE',
  'eu': 'ES',
  'fa': 'IR',
  'fi': 'FI',
  'fo': 'FO',
  'fr': 'FR',
  'gl': 'ES',
  'gu': 'IN',
  'ha': 'NG',
  'haw': 'US',
  'he': 'IL',
  'hi': 'IN',
  'hr': 'HR',
  'ht': 'HT',
  'hu': 'HU',
  'hy': 'AM',
  'id': 'ID',
  'is': 'IS',
  'it': 'IT',
  'ja': 'JP',
  'jv': 'ID',
  'ka': 'GE',
  'kk': 'KZ',
  'km': 'KH',
  'kn': 'IN',
  'ko': 'KR',
  'lb': 'LU',
  'ln': 'CD',
  'lo': 'LA',
  'lt': 'LT',
  'lv': 'LV',
  'mg': 'MG',
  'mi': 'NZ',
  'mk': 'MK',
  'ml': 'IN',
  'mn': 'MN',
  'mr': 'IN',
  'ms': 'MY',
  'mt': 'MT',
  'my': 'MM',
  'nb': 'NO',
  'ne': 'NP',
  'nl': 'NL',
  'nn': 'NO',
  'oc': 'FR',
  'pa': 'IN',
  'pl': 'PL',
  'ps': 'AF',
  'pt': 'BR',
  'ro': 'RO',
  'ru': 'RU',
  'sa': 'IN',
  'sd': 'PK',
  'si': 'LK',
  'sk': 'SK',
  'sl': 'SI',
  'sn': 'ZW',
  'so': 'SO',
  'sq': 'AL',
  'sr': 'RS',
  'su': 'ID',
  'sv': 'SE',
  'sw': 'KE',
  'ta': 'IN',
  'te': 'IN',
  'tg': 'TJ',
  'th': 'TH',
  'tk': 'TM',
  'tl': 'PH',
  'tr': 'TR',
  'tt': 'RU',
  'uk': 'UA',
  'ur': 'PK',
  'uz': 'UZ',
  'vi': 'VN',
  'yo': 'NG',
  'yue': 'HK',
  'zh': 'CN',
};

/// Major languages by global speaker count. A language not listed ranks after
/// every listed one, alphabetically.
const languagePriority = [
  'en',
  'zh',
  'hi',
  'es',
  'fr',
  'ar',
  'pt',
  'ru',
  'id',
  'de',
  'ja',
  'ko',
  'vi',
  'tr',
  'it',
  'th',
  'yue',
];

/// The supported tag a requested tag should transcribe as: the exact tag when
/// supported (case-insensitive, in the supported spelling), else a supported
/// variant of the same language (tr-GE resolves to tr-TR), else null. Only a
/// null answer may be presented as "unsupported": a device that pairs a
/// language with a region no model ships for must not read as the language
/// missing.
String? resolveSupportedTag(String tag, List<String> supported) {
  final lower = tag.toLowerCase();
  for (final candidate in supported) {
    if (candidate.toLowerCase() == lower) return candidate;
  }
  final language = lower.split('-').first;
  final variants = [
    for (final candidate in supported)
      if (candidate.toLowerCase().split('-').first == language) candidate,
  ]..sort();
  if (variants.isEmpty) return null;
  final home = languageHomeRegion[language];
  for (final variant in variants) {
    if (_regionOf(variant) == home) return variant;
  }
  for (final variant in variants) {
    if (_regionOf(variant) == language.toUpperCase()) return variant;
  }
  return variants.first;
}

/// Orders tags for every language surface: [languagePriority] languages first
/// in list order, the rest alphabetically by language; within a language the
/// [languageHomeRegion] variant leads (en-US before en-AU), then alphabetical.
int languageTagCompare(String a, String b) {
  final la = a.toLowerCase().split('-').first;
  final lb = b.toLowerCase().split('-').first;
  if (la != lb) {
    final pa = _priorityOf(la);
    final pb = _priorityOf(lb);
    if (pa != pb) return pa - pb;
    return la.compareTo(lb);
  }
  final home = languageHomeRegion[la];
  final ra = _regionOf(a);
  final rb = _regionOf(b);
  if (ra != rb) {
    if (ra == home) return -1;
    if (rb == home) return 1;
  }
  return a.toLowerCase().compareTo(b.toLowerCase());
}

int _priorityOf(String language) {
  final rank = languagePriority.indexOf(language);
  return rank < 0 ? languagePriority.length : rank;
}

String? _regionOf(String tag) {
  final parts = tag.split('-');
  return parts.length > 1 ? parts.last.toUpperCase() : null;
}
