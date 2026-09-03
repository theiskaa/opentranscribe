import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/view/widgets/app_notice.dart';

void main() {
  const four = Duration(seconds: 4);

  test('a notice holds its own duration when no screen reader is driving', () {
    expect(noticeHold(four, assisted: false), four);
  });

  test('a notice holds three times as long under a screen reader', () {
    expect(noticeHold(four, assisted: true), const Duration(seconds: 12));
  });
}
