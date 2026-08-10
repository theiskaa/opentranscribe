import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/intents/intent_actions.dart';

/// Pins the channel contract with IntentActions.swift: the method name, the
/// action names, and the preflight silence a missing plugin must produce.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const methods = MethodChannel('opentranscribe/intents');
  const events = EventChannel('opentranscribe/intents/events');

  late PlatformIntentActions intents;

  setUp(() {
    intents = PlatformIntentActions();
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(methods, null);
    messenger.setMockStreamHandler(events, null);
  });

  test('takePending asks the slot and decodes the action', () async {
    messenger.setMockMethodCallHandler(methods, (call) async {
      expect(call.method, 'takePending');
      return 'start';
    });

    expect(await intents.takePending(), IntentAction.startRecording);
  });

  test('takePending reads an empty slot as no action', () async {
    messenger.setMockMethodCallHandler(methods, (call) async => null);

    expect(await intents.takePending(), isNull);
  });

  test('takePending answers no action when the platform refuses', () async {
    messenger.setMockMethodCallHandler(methods, (call) async {
      throw PlatformException(code: 'boom');
    });

    expect(await intents.takePending(), isNull);
  });

  test('takePending answers no action with no plugin behind it', () async {
    expect(await intents.takePending(), isNull);
  });

  test('actions decodes a start and drops names and payloads it cannot read', () async {
    messenger.setMockStreamHandler(
      events,
      MockStreamHandler.inline(
        onListen: (arguments, sink) {
          sink.success('teleport');
          sink.success(42);
          sink.error(code: 'boom');
          sink.success('start');
          sink.endOfStream();
        },
      ),
    );

    expect(await intents.actions.toList(), [IntentAction.startRecording]);
  });
}
