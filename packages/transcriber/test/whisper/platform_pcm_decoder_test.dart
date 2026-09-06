import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/src/transcribe/transcription_exception.dart';
import 'package:transcriber/src/whisper/pcm_decoder.dart';
import 'package:transcriber/src/whisper/platform_pcm_decoder.dart';

/// Pins the channel contract with AudioDecode.swift: payload shape, error
/// mapping, argument guards, and one decode at a time.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const methods = MethodChannel('transcriber/audio');

  late PlatformPcmDecoder decoder;

  setUp(() => decoder = PlatformPcmDecoder());
  tearDown(() => messenger.setMockMethodCallHandler(methods, null));

  void mockMethods(Future<Object?> Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(methods, handler);
  }

  test('decode sends the path and millisecond bounds and reads back the file and frames', () async {
    Map<Object?, Object?>? sent;
    mockMethods((call) async {
      expect(call.method, 'decodePcm');
      sent = call.arguments as Map<Object?, Object?>;
      return {'path': '/scratch/otr-1.pcm', 'frames': 32000};
    });

    final decoded = await decoder.decode(
      File('/recordings/otr-a.m4a'),
      start: const Duration(milliseconds: 1500),
      end: const Duration(seconds: 4),
    );

    expect(sent, {'path': '/recordings/otr-a.m4a', 'startMs': 1500, 'endMs': 4000});
    expect(decoded, DecodedPcm(file: File('/scratch/otr-1.pcm'), frames: 32000));
    expect(decoded.duration, const Duration(seconds: 2));
  });

  test('absent bounds are left out so the native side reads the file edges', () async {
    Map<Object?, Object?>? sent;
    mockMethods((call) async {
      sent = call.arguments as Map<Object?, Object?>;
      return {'path': '/scratch/otr-2.pcm', 'frames': 16000};
    });

    await decoder.decode(File('/recordings/otr-a.m4a'));

    expect(sent, {'path': '/recordings/otr-a.m4a'});
  });

  test('a channel error maps to PcmDecodeFailed carrying the native code', () async {
    mockMethods((call) async => throw PlatformException(code: 'decode_empty', message: 'none'));

    await expectLater(
      decoder.decode(File('/recordings/otr-a.m4a'), start: const Duration(seconds: 9)),
      throwsA(
        isA<PcmDecodeFailed>()
            .having((e) => e.code, 'code', 'decode_empty')
            .having((e) => e.message, 'message', 'none'),
      ),
    );
  });

  test('a reply missing its path or frames is refused as malformed', () async {
    mockMethods((call) async => {'frames': 100});

    await expectLater(
      decoder.decode(File('/recordings/otr-a.m4a')),
      throwsA(isA<PcmDecodeFailed>().having((e) => e.code, 'code', 'decode_failed')),
    );
  });

  test('a reply of the wrong shape is refused as malformed', () async {
    mockMethods((call) async => {'path': '/scratch/x.pcm', 'frames': 'many'});

    await expectLater(
      decoder.decode(File('/recordings/otr-a.m4a')),
      throwsA(isA<PcmDecodeFailed>().having((e) => e.code, 'code', 'decode_failed')),
    );
  });

  test('a missing plugin maps to PcmDecodeFailed without a code', () async {
    await expectLater(
      decoder.decode(File('/recordings/otr-a.m4a')),
      throwsA(isA<PcmDecodeFailed>().having((e) => e.code, 'code', isNull)),
    );
  });

  test('an empty path and negative bounds are refused before the channel', () {
    var calls = 0;
    mockMethods((call) async {
      calls++;
      return null;
    });

    expect(() => decoder.decode(File('')), throwsArgumentError);
    expect(
      () => decoder.decode(File('/a.m4a'), start: const Duration(seconds: -1)),
      throwsArgumentError,
    );
    expect(
      () => decoder.decode(File('/a.m4a'), end: const Duration(seconds: -1)),
      throwsArgumentError,
    );
    expect(calls, 0);
  });

  test('two concurrent decodes run one after the other', () async {
    final order = <String>[];
    final firstGate = Completer<void>();
    mockMethods((call) async {
      final path = (call.arguments as Map)['path'] as String;
      order.add('start $path');
      if (path.endsWith('a.m4a')) await firstGate.future;
      order.add('end $path');
      return {'path': '/scratch/$path.pcm', 'frames': 1};
    });

    final first = decoder.decode(File('a.m4a'));
    final second = decoder.decode(File('b.m4a'));
    await Future<void>.delayed(Duration.zero);
    expect(order, ['start a.m4a']);

    firstGate.complete();
    await first;
    await second;

    expect(order, ['start a.m4a', 'end a.m4a', 'start b.m4a', 'end b.m4a']);
  });

  test('a failed decode does not block the next one', () async {
    mockMethods((call) async {
      final path = (call.arguments as Map)['path'] as String;
      if (path.endsWith('a.m4a')) throw PlatformException(code: 'decode_unreadable');
      return {'path': '/scratch/$path.pcm', 'frames': 7};
    });

    final first = decoder.decode(File('a.m4a'));
    final second = decoder.decode(File('b.m4a'));

    await expectLater(first, throwsA(isA<PcmDecodeFailed>()));
    expect((await second).frames, 7);
  });
}
