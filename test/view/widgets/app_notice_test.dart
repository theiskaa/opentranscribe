import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/view/widgets/app_notice.dart';

void main() {
  test('a full window notice keeps its text in the book detail safe band', () {
    final width = noticeModalWidth(modalWidth: 371, mediaWidth: 867, availableWidth: 819);
    expect(width, 323);
    expect(843 - width, greaterThanOrEqualTo(496));
    expect(843 - width / 2, 681.5);
  });

  test('a cover or tall notice keeps its existing content width', () {
    expect(noticeModalWidth(modalWidth: 382, mediaWidth: 382, availableWidth: 334), 334);
    expect(noticeModalWidth(modalWidth: 669, mediaWidth: 669, availableWidth: 621), 621);
  });

  const four = Duration(seconds: 4);

  test('a notice holds its own duration when no screen reader is driving', () {
    expect(noticeHold(four, assisted: false), four);
  });

  test('a notice holds three times as long under a screen reader', () {
    expect(noticeHold(four, assisted: true), const Duration(seconds: 12));
  });
}
