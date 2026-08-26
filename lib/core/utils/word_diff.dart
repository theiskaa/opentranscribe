/// How a [DiffSpan]'s words relate the old text to the new.
enum DiffKind { equal, added, removed }

/// One run of words the diff classified together, joined back into a string.
final class DiffSpan {
  const DiffSpan(this.kind, this.text);

  final DiffKind kind;
  final String text;

  @override
  bool operator ==(Object other) => other is DiffSpan && other.kind == kind && other.text == text;

  @override
  int get hashCode => Object.hash(kind, text);

  @override
  String toString() => '${kind.name}("$text")';
}

/// Word-level diff of [from] to [to]: what a reader must strike and what they
/// gain to get from one to the other, as ordered spans. Myers' O(ND) over
/// word tokens, so the cost scales with the SIZE OF THE CHANGE, not the text:
/// a fixed name in a thousand-word entry stays cheap. Words compare with
/// their whitespace ignored (the last word of a text must equal the same
/// word mid-sentence, and a respoken take moves whitespace everywhere), so
/// equal spans carry the [to] side's spelling: joining the equal and added
/// spans reproduces [to] exactly, while [from] survives word for word.
List<DiffSpan> diffWords(String from, String to) {
  final a = _tokens(from);
  final b = _tokens(to);
  if (a.isEmpty && b.isEmpty) return const [];

  // Trace of furthest-reaching x per diagonal, one snapshot per edit step,
  // walked backwards afterwards to recover the path.
  final n = a.length;
  final m = b.length;
  final aKeys = [for (final t in a) t.trim()];
  final bKeys = [for (final t in b) t.trim()];
  final max = n + m;
  final offset = max;
  var v = List<int>.filled(2 * max + 1, 0);
  final trace = <List<int>>[];
  var steps = -1;
  outer:
  for (var d = 0; d <= max; d++) {
    // Past this many edit steps the trace's O(D*(N+M)) memory matters more
    // than a word-level path: a full rewrite reads better as one replacement
    // anyway, and it must never grow hundreds of megabytes mid-build.
    if (d > _maxEditSteps) {
      return [
        if (from.isNotEmpty) DiffSpan(DiffKind.removed, from),
        if (to.isNotEmpty) DiffSpan(DiffKind.added, to),
      ];
    }
    trace.add(List.of(v));
    for (var k = -d; k <= d; k += 2) {
      var x = (k == -d || (k != d && v[offset + k - 1] < v[offset + k + 1]))
          ? v[offset + k + 1]
          : v[offset + k - 1] + 1;
      var y = x - k;
      while (x < n && y < m && aKeys[x] == bKeys[y]) {
        x++;
        y++;
      }
      v[offset + k] = x;
      if (x >= n && y >= m) {
        steps = d;
        break outer;
      }
    }
  }

  // Backtrack from the end, collecting per-token ops newest-first.
  final ops = <(DiffKind, String)>[];
  var x = n;
  var y = m;
  for (var d = steps; d > 0; d--) {
    v = trace[d];
    final k = x - y;
    final down = k == -d || (k != d && v[offset + k - 1] < v[offset + k + 1]);
    final prevK = down ? k + 1 : k - 1;
    final prevX = v[offset + prevK];
    final prevY = prevX - prevK;
    while (x > prevX && y > prevY) {
      ops.add((DiffKind.equal, b[y - 1]));
      x--;
      y--;
    }
    if (down) {
      ops.add((DiffKind.added, b[y - 1]));
      y--;
    } else {
      ops.add((DiffKind.removed, a[x - 1]));
      x--;
    }
  }
  while (x > 0 && y > 0) {
    ops.add((DiffKind.equal, b[y - 1]));
    x--;
    y--;
  }

  // Merge neighbours of one kind into readable runs.
  final spans = <DiffSpan>[];
  for (final (kind, text) in ops.reversed) {
    if (spans.isNotEmpty && spans.last.kind == kind) {
      spans[spans.length - 1] = DiffSpan(kind, spans.last.text + text);
    } else {
      spans.add(DiffSpan(kind, text));
    }
  }
  return spans;
}

/// A window of [spans] anchored on the first change: up to [context]
/// characters of the words before it, then everything after until [budget]
/// characters are spent. The caller's edge fade implies the rest on both
/// sides, so no ellipsis is added. All-equal input trims to the budget alone.
List<DiffSpan> diffExcerpt(List<DiffSpan> spans, {int context = 72, int budget = 240}) {
  final first = spans.indexWhere((s) => s.kind != DiffKind.equal);
  if (first == -1) {
    final text = spans.map((s) => s.text).join();
    return text.isEmpty ? const [] : [DiffSpan(DiffKind.equal, _clipEnd(text, budget))];
  }
  final out = <DiffSpan>[];
  var spent = 0;
  final before = spans.take(first).map((s) => s.text).join();
  if (before.isNotEmpty) {
    final lead = _clipStart(before, context);
    out.add(DiffSpan(DiffKind.equal, lead));
    spent = lead.length;
  }
  for (var i = first; i < spans.length; i++) {
    final span = spans[i];
    if (spent + span.text.length > budget) {
      final clipped = _clipEnd(span.text, budget - spent);
      if (clipped.isNotEmpty) out.add(DiffSpan(span.kind, clipped));
      break;
    }
    out.add(span);
    spent += span.text.length;
  }
  return out;
}

/// The last [length] UTF-16 units of [text], nudged off a surrogate seam so
/// an emoji is dropped whole rather than torn.
String _clipStart(String text, int length) {
  if (text.length <= length) return text;
  var start = text.length - length;
  if (_isLowSurrogate(text.codeUnitAt(start))) start++;
  return text.substring(start);
}

/// The first [length] UTF-16 units of [text], same surrogate care.
String _clipEnd(String text, int length) {
  if (length <= 0) return '';
  if (text.length <= length) return text;
  var end = length;
  if (_isLowSurrogate(text.codeUnitAt(end))) end--;
  return text.substring(0, end);
}

bool _isLowSurrogate(int unit) => unit >= 0xDC00 && unit <= 0xDFFF;

/// Whether two texts carry the same words, whitespace aside: [diffWords]'
/// notion of no change, shared so a history push and the diff it would render
/// can never disagree about what counts as one.
bool sameWords(String from, String to) {
  final a = _words(from);
  final b = _words(to);
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

List<String> _words(String text) => [
  for (final w in text.split(RegExp(r'\s+')))
    if (w.isNotEmpty) w,
];

/// The bail-out ceiling for [diffWords]' trace; see the loop comment.
const int _maxEditSteps = 512;

/// Words with their whitespace attached (the first word also carries the
/// text's leading run), so the spans re-join losslessly and a moved space
/// never shows up as its own change - not even at the front.
List<String> _tokens(String text) =>
    RegExp(r'\s*\S+\s*|\s+').allMatches(text).map((m) => m.group(0)!).toList();
