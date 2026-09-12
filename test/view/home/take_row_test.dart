import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/theming/type_scale.dart';
import 'package:opentranscribe/view/layouts/home/components/entry_row.dart';
import 'package:opentranscribe/view/layouts/home/components/take_row.dart';
import 'package:opentranscribe/view/widgets/invisible_ink.dart';

void main() {
  const sample = 'a few words of filler that run on and on across the row';
  const meta = '9:41 AM · 0:45';

  List<InkRow> rows(
    int characters, {
    double width = 300,
    TextScaler scaler = TextScaler.noScaling,
  }) => takeCloudRows(
    characters: characters,
    sample: sample,
    meta: meta,
    width: width,
    scaler: scaler,
    excerptLines: 4,
    bold: false,
    locale: null,
  );

  double settledHeight(
    String excerpt, {
    double width = 300,
    TextScaler scaler = TextScaler.noScaling,
  }) {
    TextPainter laid(String text, TextStyle style, {int? maxLines}) => TextPainter(
      text: TextSpan(text: text, style: AppType.body.merge(style)),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: maxLines,
      ellipsis: maxLines == null ? null : '…',
    )..layout(maxWidth: width);
    final words = laid(excerpt, EntryRowBody.excerptStyle, maxLines: 4);
    final time = laid(meta, EntryRowBody.metaStyle);
    return words.height + EntryRowBody.metaGap + time.height;
  }

  test('a short take is one line of words and the time under it', () {
    final cloud = rows(8);
    expect(cloud, hasLength(2));
    expect(cloud.first.fontSize, AppType.body.fontSize);
    expect(cloud.first.measure, lessThan(300));
    expect(cloud.last.fontSize, AppType.footnote.fontSize);
  });

  test('a cloud stands exactly as tall as the row it becomes', () {
    expect(inkRowsHeight(rows(8)), closeTo(settledHeight('a few wo'), 0.01));
    expect(inkRowsHeight(rows(2000)), closeTo(settledHeight(sample * 20), 0.01));
    const doubled = TextScaler.linear(2);
    expect(
      inkRowsHeight(rows(20, scaler: doubled)),
      closeTo(settledHeight('a few words of filler', scaler: doubled), 0.01),
    );
  });

  test('a time line that wraps at a large text size wraps in the cloud too', () {
    final cloud = rows(20, scaler: const TextScaler.linear(2));
    expect(cloud.where((row) => row.fontSize == AppType.footnote.fontSize! * 2), hasLength(2));
  });

  test('a long take stops at the lines the row shows, however long the forecast', () {
    expect(rows(400), hasLength(4 + 1));
    expect(rows(1 << 30), hasLength(4 + 1));
  });

  test('a wider row needs fewer lines for the same words', () {
    expect(rows(100, width: 800).length, lessThan(rows(100).length));
  });

  test('larger text needs more lines for the same words', () {
    expect(rows(11, scaler: const TextScaler.linear(2)).length, greaterThan(rows(11).length));
  });

  test('every line of words runs no further than the row', () {
    for (final row in rows(200)) {
      expect(row.measure, lessThanOrEqualTo(300));
    }
  });
}
