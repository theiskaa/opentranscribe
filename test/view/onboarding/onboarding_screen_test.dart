import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/view/layouts/onboarding/screens/onboarding_screen.dart';

void main() {
  test('a replay asks for the pending prompts on reaching the set-up page', () {
    expect(promptsOnArrival(replay: true, page: 3, pageCount: 4), isTrue);
    expect(promptsOnArrival(replay: true, page: 2, pageCount: 3), isTrue);
  });

  test('a replay asks nothing on the pages before it', () {
    expect(promptsOnArrival(replay: true, page: 0, pageCount: 4), isFalse);
    expect(promptsOnArrival(replay: true, page: 2, pageCount: 4), isFalse);
  });

  test('a first run leaves the asking to the last button', () {
    expect(promptsOnArrival(replay: false, page: 3, pageCount: 4), isFalse);
  });
}
