import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/intents/intent_action_service.dart';
import 'package:opentranscribe/core/intents/intent_actions.dart';

import '../../support/fake_intent_actions.dart';

void main() {
  late FakeIntentActions actions;
  late int opened;
  late bool canOpen;

  IntentActionService serviceFor() => IntentActionService(
    source: actions,
    canOpenRecorder: () => canOpen,
    openRecorder: () => opened++,
  );

  setUp(() {
    actions = FakeIntentActions();
    opened = 0;
    canOpen = true;
  });

  tearDown(() => actions.close());

  group('serve', () {
    test('a launch asked to record opens the recorder', () async {
      actions.pending = IntentAction.startRecording;
      await serviceFor().serve();

      expect(opened, 1);
    });

    test('a launch nobody asked to record leaves the recorder closed', () async {
      await serviceFor().serve();

      expect(opened, 0);
    });

    test('an action arriving while the app runs opens the recorder', () async {
      await serviceFor().serve();
      await actions.emit(IntentAction.startRecording);

      expect(opened, 1);
    });

    test('the stream is listened to before the first drain', () async {
      actions.pending = IntentAction.startRecording;
      final service = serviceFor();
      final serving = service.serve();

      expect(actions.hasListener, isTrue);
      await serving;
    });

    test('serving twice keeps a single subscription', () async {
      final service = serviceFor();
      await service.serve();
      await service.serve();
      await actions.emit(IntentAction.startRecording);

      expect(opened, 1);
    });
  });

  group('drain', () {
    test('a resume before serving leaves the action for the first serve', () async {
      final service = serviceFor();
      actions.pending = IntentAction.startRecording;
      await service.drain();

      expect(actions.takeCount, 0);
      expect(actions.pending, IntentAction.startRecording);

      await service.serve();

      expect(opened, 1);
    });

    test('a resume while serving opens the recorder', () async {
      final service = serviceFor();
      await service.serve();
      actions.pending = IntentAction.startRecording;
      await service.drain();

      expect(opened, 1);
    });
  });

  group('canOpenRecorder', () {
    test('a refused action opens nothing, from either path', () async {
      canOpen = false;
      final service = serviceFor();
      actions.pending = IntentAction.startRecording;
      await service.serve();
      await actions.emit(IntentAction.startRecording);

      expect(opened, 0);
    });
  });

  group('dispose', () {
    test('a disposed service stops acting on the stream', () async {
      final service = serviceFor();
      await service.serve();
      await service.dispose();
      await actions.emit(IntentAction.startRecording);

      expect(opened, 0);
    });
  });
}
