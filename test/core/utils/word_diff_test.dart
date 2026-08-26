import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/utils/word_diff.dart';

void main() {
  String fromSide(List<DiffSpan> spans) => [
    for (final s in spans)
      if (s.kind != DiffKind.added) s.text,
  ].join();

  String toSide(List<DiffSpan> spans) => [
    for (final s in spans)
      if (s.kind != DiffKind.removed) s.text,
  ].join();

  test('identical texts are one equal span', () {
    final spans = diffWords('went for a walk', 'went for a walk');
    expect(spans, [const DiffSpan(DiffKind.equal, 'went for a walk')]);
  });

  test('a replaced word strikes the old and adds the new', () {
    final spans = diffWords('went for a walk today', 'went for a stroll today');
    expect(spans.where((s) => s.kind == DiffKind.removed).single.text.trim(), 'walk');
    expect(spans.where((s) => s.kind == DiffKind.added).single.text.trim(), 'stroll');
  });

  test('the to side reproduces exactly, the from side word for word', () {
    const from = 'the quick brown fox  jumps\nover the lazy dog';
    const to = 'a quick red fox jumps over one lazy cat';
    final spans = diffWords(from, to);
    expect(toSide(spans), to);
    expect(fromSide(spans).split(RegExp(r'\s+')), from.split(RegExp(r'\s+')));
  });

  test('appending a word never strikes the old last word', () {
    final spans = diffWords('hello world', 'hello world today');
    expect(spans.where((s) => s.kind == DiffKind.removed), isEmpty);
    expect(spans.where((s) => s.kind == DiffKind.added).single.text.trim(), 'today');
  });

  test('an empty side is all one kind', () {
    expect(diffWords('', 'all new words').single.kind, DiffKind.added);
    expect(diffWords('all gone words', '').single.kind, DiffKind.removed);
    expect(diffWords('', ''), isEmpty);
  });

  test('neighbouring changes merge into runs', () {
    final spans = diffWords('one two three four', 'one five six four');
    expect(spans.map((s) => s.kind), [
      DiffKind.equal,
      DiffKind.removed,
      DiffKind.added,
      DiffKind.equal,
    ]);
  });

  test('a whitespace-only difference is no change at all', () {
    final spans = diffWords('hello  world ', 'hello world');
    expect(spans.single.kind, DiffKind.equal);
    expect(toSide(spans), 'hello world');
  });

  test('a leading space never diffs as its own change', () {
    expect(diffWords(' hello', 'hello'), [const DiffSpan(DiffKind.equal, 'hello')]);
    expect(diffWords('fixed', ' fixed '), [const DiffSpan(DiffKind.equal, ' fixed ')]);
  });

  test('a full rewrite collapses to one replacement instead of a huge trace', () {
    final from = List.generate(3000, (i) => 'old$i').join(' ');
    final to = List.generate(3000, (i) => 'new$i').join(' ');
    final spans = diffWords(from, to);
    expect(spans, [DiffSpan(DiffKind.removed, from), DiffSpan(DiffKind.added, to)]);
  });

  test('a large text with a small change stays a small diff', () {
    final words = List.generate(2000, (i) => 'word$i').join(' ');
    final changed = words.replaceFirst('word1000', 'fixed');
    final spans = diffWords(words, changed);
    expect(spans.where((s) => s.kind != DiffKind.equal), hasLength(2));
  });

  test('an excerpt windows around the first change with leading context', () {
    final long = List.generate(200, (i) => 'w$i').join(' ');
    final changed = long.replaceFirst('w100', 'fixed');
    final excerpt = diffExcerpt(diffWords(long, changed));

    final joined = excerpt.map((s) => s.text).join();
    expect(joined.length, lessThanOrEqualTo(240));
    expect(excerpt.first.kind, DiffKind.equal);
    expect(excerpt.any((s) => s.kind == DiffKind.added && s.text.trim() == 'fixed'), isTrue);
    expect(joined, isNot(startsWith('w0 ')));
  });

  test('an all-equal excerpt trims to the budget alone', () {
    final long = List.generate(200, (i) => 'w$i').join(' ');
    final excerpt = diffExcerpt(diffWords(long, long));
    expect(excerpt.single.kind, DiffKind.equal);
    expect(excerpt.single.text.length, lessThanOrEqualTo(240));
  });

  test('a short diff excerpts to itself and empty stays empty', () {
    final spans = diffWords('one two', 'one three');
    expect(diffExcerpt(spans), spans);
    expect(diffExcerpt(const []), isEmpty);
  });

  test('an excerpt clip never tears a surrogate pair', () {
    final long = '${List.generate(60, (i) => '😀word$i').join(' ')} tail';
    final changed = long.replaceFirst('tail', 'fixed');
    for (final span in diffExcerpt(diffWords(long, changed), context: 7, budget: 21)) {
      expect(span.text.runes.toList, returnsNormally);
      if (span.text.isNotEmpty) {
        expect(span.text.codeUnitAt(0) & 0xFC00 == 0xDC00, isFalse);
      }
    }
  });

  test('sameWords sees through whitespace and nothing else', () {
    expect(sameWords('hello  world ', 'hello world'), isTrue);
    expect(sameWords(' hello\nworld', 'hello world'), isTrue);
    expect(sameWords('hello world', 'hello there'), isFalse);
    expect(sameWords('hello world', 'hello world again'), isFalse);
    expect(sameWords('', '   '), isTrue);
  });
}
