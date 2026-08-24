import 'package:opentranscribe/core/state/settings_cubit.dart';
import 'package:opentranscribe/view/widgets/locale_names.dart';

/// The rows [query] keeps: a case- and accent-lax match on the localized
/// display name and on the BCP-47 tag, so "francais", "Français" and "fr" all
/// find French. Pure, one rule for every language search.
List<LanguageModelState> filterLanguageRows(String query, List<LanguageModelState> rows) {
  final needle = _fold(query);
  if (needle.isEmpty) return rows;
  return [
    for (final row in rows)
      if (_fold(localeDisplayName(row.tag)).contains(needle) ||
          row.tag.toLowerCase().contains(needle))
        row,
  ];
}

/// A broad Latin fold, not a full Unicode pass: covers the accents the
/// rendered display names carry and the plain spellings a query types for
/// them.
const _accents = {
  'à': 'a',
  'á': 'a',
  'â': 'a',
  'ã': 'a',
  'ä': 'a',
  'å': 'a',
  'ç': 'c',
  'è': 'e',
  'é': 'e',
  'ê': 'e',
  'ë': 'e',
  'ì': 'i',
  'í': 'i',
  'î': 'i',
  'ï': 'i',
  'ñ': 'n',
  'ò': 'o',
  'ó': 'o',
  'ô': 'o',
  'õ': 'o',
  'ö': 'o',
  'ù': 'u',
  'ú': 'u',
  'û': 'u',
  'ü': 'u',
  'ý': 'y',
  'ș': 's',
  'ş': 's',
  'ț': 't',
  'ế': 'e',
  'ệ': 'e',
  'ā': 'a',
  'ē': 'e',
  'ī': 'i',
  'ō': 'o',
  'ū': 'u',
};

String _fold(String value) {
  final lower = value.trim().toLowerCase();
  final out = StringBuffer();
  for (final char in lower.split('')) {
    out.write(_accents[char] ?? char);
  }
  return out.toString();
}
