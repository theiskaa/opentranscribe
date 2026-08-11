import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/app/splash_handoff.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel('opentranscribe/splash');

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('finish calls the native finish method', () async {
    final calls = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call.method);
      return null;
    });
    await SplashHandoff().finish();
    expect(calls, ['finish']);
  });

  test('finish stays silent with no plugin behind the channel', () async {
    await expectLater(SplashHandoff().finish(), completes);
  });

  test('finish swallows a platform error, the splash is cosmetic', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'boom');
    });
    await expectLater(SplashHandoff().finish(), completes);
  });
}
