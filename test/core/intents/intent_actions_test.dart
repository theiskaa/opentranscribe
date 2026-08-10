import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/intents/intent_actions.dart';

void main() {
  group('intentActionFromName', () {
    test('start is the recorder', () {
      expect(intentActionFromName('start'), IntentAction.startRecording);
    });

    test('a name this build does not know is dropped', () {
      expect(intentActionFromName('teleport'), isNull);
    });

    test('a missing name is dropped', () {
      expect(intentActionFromName(null), isNull);
    });
  });
}
