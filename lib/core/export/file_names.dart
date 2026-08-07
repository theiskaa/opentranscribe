/// Characters no exported file name may carry: path separators, the
/// Windows-reserved set, and anything below space. Stripped, not escaped,
/// so names stay human on every filesystem an export can land on.
final _reserved = RegExp(r'[\x00-\x1f/\\:*?"<>|]');

final _whitespace = RegExp(r'\s+');

final _edgeDots = RegExp(r'^\.+|\.+$');

/// Windows device names, which Explorer refuses or mangles on extraction
/// even inside a zip. Matched against the part before the first dot.
final _windowsDevice = RegExp(r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])(\.|$)', caseSensitive: false);

/// Returns [raw] reduced to a safe cross-platform file name: whitespace
/// collapsed, reserved characters stripped, edges trimmed of blanks and
/// dots, capped at [maxLength] runes, device names defused. Falls back to
/// [fallback] when nothing legible survives, so the result is never empty.
String sanitizeFileName(String raw, {String fallback = 'untitled', int maxLength = 80}) {
  var name = raw.replaceAll(_whitespace, ' ').replaceAll(_reserved, '').trim();
  name = name.replaceAll(_edgeDots, '').trim();
  // Runes, not code units, so the cap can never split a surrogate pair. The
  // cap can expose a new trailing dot, so the edge strip runs again after.
  if (name.runes.length > maxLength) {
    name = String.fromCharCodes(name.runes.take(maxLength));
    name = name.trim().replaceAll(_edgeDots, '').trim();
  }
  if (_windowsDevice.hasMatch(name)) {
    final dot = name.indexOf('.');
    name = dot < 0 ? '$name-' : '${name.substring(0, dot)}-${name.substring(dot)}';
  }
  if (name.isEmpty) return fallback;
  return name;
}

/// The final '/'-separated segment: what the export feature means by a bare
/// audio filename, shared so five call sites cannot drift.
String baseName(String path) => path.split('/').last;

/// Returns [name], or its first `base-N.ext` variant not present in [taken].
/// Deterministic: the same name against the same set always answers the same,
/// so an exporter producing colliding titles stays reproducible.
String uniqueFileName(String name, Set<String> taken) {
  if (!taken.contains(name)) return name;
  final dot = name.lastIndexOf('.');
  final base = dot > 0 ? name.substring(0, dot) : name;
  final ext = dot > 0 ? name.substring(dot) : '';
  for (var n = 2; ; n++) {
    final candidate = '$base-$n$ext';
    if (!taken.contains(candidate)) return candidate;
  }
}
