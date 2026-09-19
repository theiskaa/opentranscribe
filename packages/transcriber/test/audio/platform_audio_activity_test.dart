import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/src/audio/platform_audio_activity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const methods = MethodChannel('transcriber/audio');
  final audio = File('/recordings/otr-a.m4a');

  late PlatformAudioActivity activity;

  setUp(() => activity = PlatformAudioActivity());
  tearDown(() => messenger.setMockMethodCallHandler(methods, null));

  void mockMethods(Future<Object?> Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(methods, handler);
  }

  test('asks for the path and millisecond bounds and reads back the voiced ranges', () async {
    Map<Object?, Object?>? sent;
    mockMethods((call) async {
      expect(call.method, 'voicedRanges');
      sent = call.arguments as Map<Object?, Object?>;
      return {
        'ranges': [
          [1200, 3400],
          [5000, 9000],
        ],
      };
    });

    final voiced = await activity.voiced(
      audio,
      start: const Duration(seconds: 1),
      end: const Duration(seconds: 10),
    );

    expect(sent, {'path': '/recordings/otr-a.m4a', 'startMs': 1000, 'endMs': 10000});
    expect(voiced, [
      (start: const Duration(milliseconds: 1200), end: const Duration(milliseconds: 3400)),
      (start: const Duration(seconds: 5), end: const Duration(seconds: 9)),
    ]);
  });

  test('no bounds asks about the whole file', () async {
    Map<Object?, Object?>? sent;
    mockMethods((call) async {
      sent = call.arguments as Map<Object?, Object?>;
      return {'ranges': <Object?>[]};
    });

    expect(await activity.voiced(audio), isEmpty);
    expect(sent, {'path': '/recordings/otr-a.m4a'});
  });

  test('a refusing platform or a malformed reply answers that it cannot tell', () async {
    mockMethods((call) async => throw PlatformException(code: 'decode_unreadable'));
    expect(await activity.voiced(audio), isNull);

    mockMethods((call) async => {'ranges': 'nonsense'});
    expect(await activity.voiced(audio), isNull);

    mockMethods(
      (call) async => {
        'ranges': [
          [1200],
        ],
      },
    );
    expect(await activity.voiced(audio), isNull);

    mockMethods((call) async => null);
    expect(await activity.voiced(audio), isNull);

    mockMethods((call) async => 'not a map');
    expect(await activity.voiced(audio), isNull);
  });

  test('a probe that cannot say where the voice is answers that it cannot tell', () async {
    mockMethods((call) async => {'ranges': null});

    expect(await activity.voiced(audio), isNull);
  });

  test('a range that ends before it starts is a malformed reply', () async {
    mockMethods(
      (call) async => {
        'ranges': [
          [3000, 1000],
        ],
      },
    );

    expect(await activity.voiced(audio), isNull);
  });

  test('an empty path or a negative bound is not asked at all', () async {
    var asked = false;
    mockMethods((call) async {
      asked = true;
      return {'ranges': <Object?>[]};
    });

    expect(await activity.voiced(File('')), isNull);
    expect(await activity.voiced(audio, start: const Duration(seconds: -1)), isNull);
    expect(asked, isFalse);
  });
}
