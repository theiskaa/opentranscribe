import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/src/audio/platform_audio_composer.dart';
import 'package:transcriber/src/audio/recording.dart';
import 'package:transcriber/src/transcribe/transcription_exception.dart';

/// Pins the channel contract with AudioCompose.swift: payload shape, error
/// mapping, argument guards, and one merge at a time.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const methods = MethodChannel('transcriber/audio');

  late PlatformAudioComposer composer;

  setUp(() => composer = PlatformAudioComposer());
  tearDown(() => messenger.setMockMethodCallHandler(methods, null));

  void mockMethods(Future<Object?> Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(methods, handler);
  }

  test('concatenate sends the names in order and decodes name, duration and starts', () async {
    List<Object?>? sent;
    mockMethods((call) async {
      expect(call.method, 'concatenate');
      sent = (call.arguments as Map)['names'] as List<Object?>;
      return {
        'name': 'otr-out.m4a',
        'durationMs': 5000,
        'startsMs': [0, 3000],
      };
    });

    final composition = await composer.concatenate(['otr-a.m4a', 'otr-b.m4a']);

    expect(sent, ['otr-a.m4a', 'otr-b.m4a']);
    expect(
      composition,
      Composition(
        name: 'otr-out.m4a',
        duration: const Duration(seconds: 5),
        starts: const [Duration.zero, Duration(seconds: 3)],
      ),
    );
  });

  test('a channel error maps to AudioComposeFailed carrying the native code', () async {
    mockMethods((call) async => throw PlatformException(code: 'compose_missing', message: 'gone'));

    await expectLater(
      composer.concatenate(['otr-a.m4a', 'otr-b.m4a']),
      throwsA(
        isA<AudioComposeFailed>()
            .having((e) => e.code, 'code', 'compose_missing')
            .having((e) => e.message, 'message', 'gone'),
      ),
    );
  });

  test('a missing plugin maps to AudioComposeFailed without a code', () async {
    await expectLater(
      composer.concatenate(['otr-a.m4a', 'otr-b.m4a']),
      throwsA(isA<AudioComposeFailed>().having((e) => e.code, 'code', isNull)),
    );
  });

  test('a reply without a name or with the wrong start count is a failure', () async {
    Future<void> expectFailure(Object? reply) async {
      mockMethods((_) async => reply);
      await expectLater(
        composer.concatenate(['otr-a.m4a', 'otr-b.m4a']),
        throwsA(isA<AudioComposeFailed>().having((e) => e.message, 'message', 'malformed reply')),
      );
    }

    await expectFailure(null);
    await expectFailure({
      'durationMs': 5,
      'startsMs': [0, 1],
    });
    await expectFailure({
      'name': 'otr-out.m4a',
      'durationMs': 5,
      'startsMs': [0],
    });
    await expectFailure({
      'name': 'otr-out.m4a',
      'durationMs': 5,
      'startsMs': [1, 2],
    });
  });

  test('fewer than two names or a path is refused before the channel is touched', () async {
    var calls = 0;
    mockMethods((call) async {
      calls++;
      return null;
    });

    expect(() => composer.concatenate(['otr-a.m4a']), throwsArgumentError);
    expect(() => composer.concatenate(['otr-a.m4a', 'sub/otr-b.m4a']), throwsArgumentError);
    expect(() => composer.concatenate(['otr-a.m4a', '']), throwsArgumentError);
    expect(calls, 0);
  });

  test('two concurrent merges run one after the other', () async {
    final first = Completer<void>();
    final order = <String>[];
    mockMethods((call) async {
      final names = (call.arguments as Map)['names'] as List<Object?>;
      order.add('start ${names.first}');
      if (names.first == 'otr-a.m4a') await first.future;
      order.add('end ${names.first}');
      return {
        'name': 'otr-out.m4a',
        'durationMs': 1,
        'startsMs': [0, 0],
      };
    });

    final a = composer.concatenate(['otr-a.m4a', 'otr-b.m4a']);
    final b = composer.concatenate(['otr-c.m4a', 'otr-d.m4a']);
    await Future<void>.delayed(Duration.zero);
    expect(order, ['start otr-a.m4a']);
    first.complete();
    await Future.wait([a, b]);

    expect(order, ['start otr-a.m4a', 'end otr-a.m4a', 'start otr-c.m4a', 'end otr-c.m4a']);
  });

  test('a failed merge does not block the next one', () async {
    var call = 0;
    mockMethods((_) async {
      if (call++ == 0) throw PlatformException(code: 'compose_failed');
      return {
        'name': 'otr-out.m4a',
        'durationMs': 1,
        'startsMs': [0, 0],
      };
    });

    await expectLater(
      composer.concatenate(['otr-a.m4a', 'otr-b.m4a']),
      throwsA(isA<AudioComposeFailed>()),
    );
    final composition = await composer.concatenate(['otr-c.m4a', 'otr-d.m4a']);

    expect(composition.name, 'otr-out.m4a');
  });
}
