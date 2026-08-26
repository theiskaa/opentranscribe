import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/src/transcribe/apple_speech_engines.dart';
import 'package:transcriber/src/transcribe/transcript.dart';
import 'package:transcriber/src/transcribe/transcript_event.dart';
import 'package:transcriber/src/transcribe/transcription_engine.dart';
import 'package:transcriber/src/transcribe/transcription_exception.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const methods = MethodChannel('transcriber/speech');
  const events = EventChannel('transcriber/speech/events');
  const modelEvents = EventChannel('transcriber/speech/model');
  final fixedClock = DateTime.utc(2026, 3, 4, 12);

  late AppleSpeechEngine engine;

  setUp(() {
    engine = AppleSpeechEngine(clock: () => fixedClock, live: SpeechLiveTransport());
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(methods, null);
    messenger.setMockStreamHandler(events, null);
    messenger.setMockStreamHandler(modelEvents, null);
  });

  void mockMethods(Future<Object?> Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(methods, handler);
  }

  group('transcribeFile', () {
    test('decodes a full reply, dropping malformed segments', () async {
      mockMethods((call) async {
        expect(call.method, 'transcribeFile');
        expect((call.arguments as Map)['localeId'], 'en-US');
        return {
          'text': 'hello world',
          'segments': [
            {'text': 'hello', 'startMs': 0, 'endMs': 500, 'confidence': 0.9},
            {'text': 'untimed'}, // missing timing: dropped, like the native side
            'not-a-map', // junk: dropped
          ],
        };
      });

      final transcript = await engine.transcribeFile(File('/tmp/a.m4a'), localeId: 'en-US');

      expect(transcript.fullText, 'hello world');
      expect(transcript.segments, [
        const TranscriptSegment(
          text: 'hello',
          start: Duration.zero,
          end: Duration(milliseconds: 500),
          confidence: 0.9,
        ),
      ]);
      expect(transcript.engineId, 'apple.speech');
      expect(transcript.localeId, 'en-US');
      expect(transcript.createdAt, fixedClock);
    });

    test('a null reply is a protocol breach, not an empty transcript', () async {
      mockMethods((call) async => null);

      await expectLater(
        engine.transcribeFile(File('/tmp/a.m4a'), localeId: 'en-US'),
        throwsA(isA<TranscriptionFailed>()),
      );
    });

    test('maps every native error code to its typed exception', () async {
      Future<void> expectCode(String code, Matcher matcher) async {
        mockMethods((call) async => throw PlatformException(code: code, message: 'msg'));
        await expectLater(
          engine.transcribeFile(File('/tmp/a.m4a'), localeId: 'en-US'),
          throwsA(matcher),
        );
      }

      await expectCode('permission_denied', isA<PermissionDenied>());
      await expectCode('on_device_unavailable', isA<OnDeviceUnavailable>());
      await expectCode('model_install_failed', isA<ModelInstallFailed>());
      await expectCode('reservation_cap', isA<ReservationCapReached>());
      await expectCode('file_missing', isA<TranscriptionFailed>());
      await expectCode('transcribe_error', isA<TranscriptionFailed>());
      await expectCode('bad_args', isA<TranscriptionFailed>());
    });

    test('structured details ride into the typed exceptions', () async {
      mockMethods(
        (call) async => throw PlatformException(
          code: 'model_install_failed',
          message: 'download failed',
          details: {'status': 'downloading'},
        ),
      );
      await expectLater(
        engine.transcribeFile(File('/tmp/a.m4a'), localeId: 'en-US'),
        throwsA(
          isA<ModelInstallFailed>().having(
            (e) => e.assetStatus,
            'assetStatus',
            ModelAssetStatus.downloading,
          ),
        ),
      );

      mockMethods(
        (call) async => throw PlatformException(
          code: 'reservation_cap',
          message: 'full',
          details: {
            'reservedTags': ['de-DE', 'en-US'],
          },
        ),
      );
      await expectLater(
        engine.transcribeFile(File('/tmp/a.m4a'), localeId: 'fr-FR'),
        throwsA(
          isA<ReservationCapReached>().having((e) => e.reservedTags, 'reservedTags', [
            'de-DE',
            'en-US',
          ]),
        ),
      );
    });
  });

  group('transcribeFile slices', () {
    test('bounds ride the channel as milliseconds; whole files omit them', () async {
      Map<Object?, Object?>? seenArgs;
      mockMethods((call) async {
        seenArgs = call.arguments as Map<Object?, Object?>;
        return {'text': '', 'segments': <Object?>[]};
      });

      await engine.transcribeFile(
        File('/tmp/a.m4a'),
        localeId: 'en-US',
        start: const Duration(seconds: 5),
        end: const Duration(seconds: 9),
      );
      expect(seenArgs?['startMs'], 5000);
      expect(seenArgs?['endMs'], 9000);

      await engine.transcribeFile(File('/tmp/a.m4a'), localeId: 'en-US');
      expect(seenArgs?.containsKey('startMs'), isFalse);
      expect(seenArgs?.containsKey('endMs'), isFalse);
    });
  });

  group('cancelBatches', () {
    test('invokes the native method and swallows failures', () async {
      var called = false;
      mockMethods((call) async {
        expect(call.method, 'cancelBatches');
        called = true;
        return null;
      });

      await engine.cancelBatches();
      expect(called, isTrue);

      mockMethods((call) async => throw PlatformException(code: 'x'));
      await engine.cancelBatches();

      messenger.setMockMethodCallHandler(methods, null); // missing plugin
      await engine.cancelBatches();
    });
  });

  group('supportedLocales', () {
    test('decodes the tag list, empty on error or missing plugin', () async {
      mockMethods((call) async {
        expect(call.method, 'supportedLocales');
        return ['de-DE', 'en-US'];
      });
      expect(await engine.supportedLocales(), ['de-DE', 'en-US']);

      mockMethods((call) async => throw PlatformException(code: 'x'));
      expect(await engine.supportedLocales(), isEmpty);

      messenger.setMockMethodCallHandler(methods, null); // missing plugin
      expect(await engine.supportedLocales(), isEmpty);
    });
  });

  group('missing plugin', () {
    test('checkAvailability degrades, isModelInstalled is false, actions throw typed', () async {
      final availability = await engine.checkAvailability(localeId: 'en-US');
      expect(availability.status, AvailabilityStatus.onDeviceUnavailable);

      expect(await engine.isModelInstalled(localeId: 'en-US'), isFalse);

      await expectLater(
        engine.transcribeFile(File('/tmp/a.m4a'), localeId: 'en-US'),
        throwsA(isA<TranscriptionFailed>()),
      );
    });
  });

  group('checkAvailability', () {
    test('maps status strings, unknown to onDeviceUnavailable', () async {
      Future<AvailabilityStatus> statusFor(String raw) async {
        mockMethods((call) async => {'status': raw});
        return (await engine.checkAvailability(localeId: 'en-US')).status;
      }

      expect(await statusFor('available'), AvailabilityStatus.available);
      expect(await statusFor('permission_denied'), AvailabilityStatus.permissionDenied);
      expect(await statusFor('on_device_unavailable'), AvailabilityStatus.onDeviceUnavailable);
      expect(await statusFor('bogus'), AvailabilityStatus.onDeviceUnavailable);
    });

    test('a channel error becomes unavailable with detail, never a throw', () async {
      mockMethods((call) async => throw PlatformException(code: 'x', message: 'broken'));

      final availability = await engine.checkAvailability(localeId: 'en-US');

      expect(availability.status, AvailabilityStatus.onDeviceUnavailable);
      expect(availability.detail, 'broken');
    });

    test('a null reply degrades to unavailable', () async {
      mockMethods((call) async => null);

      final availability = await engine.checkAvailability(localeId: 'en-US');

      expect(availability.status, AvailabilityStatus.onDeviceUnavailable);
    });
  });

  group('isModelInstalled', () {
    test('passes the native bool through, false on null or error', () async {
      mockMethods((call) async => true);
      expect(await engine.isModelInstalled(localeId: 'en-US'), isTrue);

      mockMethods((call) async => null);
      expect(await engine.isModelInstalled(localeId: 'en-US'), isFalse);

      mockMethods((call) async => throw PlatformException(code: 'x'));
      expect(await engine.isModelInstalled(localeId: 'en-US'), isFalse);
    });
  });

  group('installedLocales', () {
    test('decodes the tag list, empty on error or missing plugin', () async {
      mockMethods((call) async {
        expect(call.method, 'installedLocales');
        return ['en-US', 'ru-RU'];
      });
      expect(await engine.installedLocales(), ['en-US', 'ru-RU']);

      mockMethods((call) async => throw PlatformException(code: 'x'));
      expect(await engine.installedLocales(), isEmpty);

      messenger.setMockMethodCallHandler(methods, null); // missing plugin
      expect(await engine.installedLocales(), isEmpty);
    });
  });

  group('localeStatus', () {
    test('decodes the full state map', () async {
      mockMethods((call) async {
        expect(call.method, 'localeStatus');
        expect((call.arguments as Map)['localeId'], 'de-AT');
        return {'status': 'installed', 'reserved': true, 'resolvedTag': 'de-DE'};
      });

      final status = await engine.localeStatus(localeId: 'de-AT');

      expect(
        status,
        const LocaleModelStatus(
          status: ModelAssetStatus.installed,
          reserved: true,
          resolvedTag: 'de-DE',
        ),
      );
      expect(status.isReady, isTrue);
    });

    test('every status string maps; junk and errors read as downloadable-not-ready', () async {
      Future<ModelAssetStatus> statusFor(String raw) async {
        mockMethods((call) async => {'status': raw, 'reserved': false, 'resolvedTag': 'x'});
        return (await engine.localeStatus(localeId: 'x')).status;
      }

      expect(await statusFor('unsupported'), ModelAssetStatus.unsupported);
      expect(await statusFor('supported'), ModelAssetStatus.supported);
      expect(await statusFor('downloading'), ModelAssetStatus.downloading);
      expect(await statusFor('installed'), ModelAssetStatus.installed);
      expect(await statusFor('bogus'), ModelAssetStatus.supported);

      mockMethods((call) async => throw PlatformException(code: 'x'));
      final onError = await engine.localeStatus(localeId: 'en-US');
      expect(onError.status, ModelAssetStatus.supported);
      expect(onError.reserved, isFalse);
      expect(onError.resolvedTag, 'en-US');

      messenger.setMockMethodCallHandler(methods, null); // missing plugin
      expect((await engine.localeStatus(localeId: 'en-US')).status, ModelAssetStatus.supported);
    });
  });

  group('removeLanguage', () {
    test('passes the native bool through, false on null or error', () async {
      mockMethods((call) async {
        expect(call.method, 'removeLanguage');
        expect((call.arguments as Map)['localeId'], 'ru-RU');
        return true;
      });
      expect(await engine.removeLanguage(localeId: 'ru-RU'), isTrue);

      mockMethods((call) async => null);
      expect(await engine.removeLanguage(localeId: 'ru-RU'), isFalse);

      mockMethods((call) async => throw PlatformException(code: 'x'));
      expect(await engine.removeLanguage(localeId: 'ru-RU'), isFalse);
    });
  });

  group('reservationInfo', () {
    test('decodes max and tags, max 0 (no cap) on error or missing plugin', () async {
      mockMethods((call) async {
        expect(call.method, 'reservationInfo');
        return {
          'max': 3,
          'reserved': ['en-US', 'ru-RU'],
        };
      });

      final info = await engine.reservationInfo();
      expect(info.max, 3);
      expect(info.reservedTags, ['en-US', 'ru-RU']);

      mockMethods((call) async => throw PlatformException(code: 'x'));
      expect((await engine.reservationInfo()).max, 0);

      messenger.setMockMethodCallHandler(methods, null); // missing plugin
      final missing = await engine.reservationInfo();
      expect(missing.max, 0);
      expect(missing.reservedTags, isEmpty);
    });
  });

  group('transcribeLive', () {
    MockStreamHandlerEventSink? liveSink;
    final started = <int>[];
    final stopped = <int>[];

    void mockLive() {
      started.clear();
      stopped.clear();
      messenger.setMockStreamHandler(
        events,
        MockStreamHandler.inline(onListen: (arguments, sink) => liveSink = sink),
      );
      mockMethods((call) async {
        final args = call.arguments as Map?;
        if (call.method == 'startLive') started.add(args!['session'] as int);
        if (call.method == 'stopLive') stopped.add(args!['session'] as int);
        return null;
      });
    }

    test('yields partials then completes on the final event', () async {
      mockLive();
      final done = engine.transcribeLive(localeId: 'en-US').toList();
      await Future<void>.delayed(Duration.zero);
      final s = started.single;
      liveSink!.success({'session': s, 'text': 'hel', 'isFinal': false});
      liveSink!.success({
        'session': s,
        'text': 'hello',
        'isFinal': true,
        'segments': [
          {'text': 'hello', 'startMs': 0, 'endMs': 700},
        ],
      });

      expect(await done, [
        const TranscriptEvent(text: 'hel', isFinal: false),
        const TranscriptEvent(
          text: 'hello',
          isFinal: true,
          segments: [
            TranscriptSegment(
              text: 'hello',
              start: Duration.zero,
              end: Duration(milliseconds: 700),
            ),
          ],
        ),
      ]);
    });

    test('an error payload becomes the typed exception', () async {
      mockLive();
      final done = engine.transcribeLive(localeId: 'en-US').toList();
      await Future<void>.delayed(Duration.zero);
      liveSink!.success({
        'session': started.single,
        'type': 'error',
        'code': 'permission_denied',
        'message': 'no',
      });
      await expectLater(done, throwsA(isA<PermissionDenied>()));
    });

    test('the final event stops the session natively', () async {
      mockLive();
      final done = engine.transcribeLive(localeId: 'en-US').toList();
      await Future<void>.delayed(Duration.zero);
      final s = started.single;
      liveSink!.success({'session': s, 'text': 'done', 'isFinal': true});

      expect(await done, [const TranscriptEvent(text: 'done', isFinal: true)]);
      expect(stopped, contains(s));
    });

    test('concurrent sessions route by token; each stream sees only its own', () async {
      mockLive();
      final aEvents = <TranscriptEvent>[];
      final bEvents = <TranscriptEvent>[];
      final a = engine.transcribeLive(localeId: 'en-US').listen(aEvents.add);
      final b = engine.transcribeLive(localeId: 'fr-FR').listen(bEvents.add);
      await Future<void>.delayed(Duration.zero);
      expect(started.length, 2);
      final (sa, sb) = (started[0], started[1]);

      liveSink!.success({'session': sa, 'text': 'alpha', 'isFinal': false});
      liveSink!.success({'session': sb, 'text': 'bravo', 'isFinal': false});
      liveSink!.success({'session': sa, 'text': 'alpha done', 'isFinal': true});
      await Future<void>.delayed(Duration.zero);

      expect(aEvents.map((e) => e.text), ['alpha', 'alpha done']);
      expect(bEvents.map((e) => e.text), ['bravo'], reason: 'b never sees a\'s events');

      await a.cancel();
      await b.cancel();
    });
  });

  group('installModel', () {
    test('streams progress and completes on done', () async {
      messenger.setMockStreamHandler(
        modelEvents,
        MockStreamHandler.inline(
          onListen: (arguments, sink) {
            expect((arguments as Map?)?['localeId'], 'en-US');
            sink.success({'fraction': 0.4, 'done': false});
            sink.success({'fraction': 1.0, 'done': true});
          },
        ),
      );

      final progress = await engine.installModel(localeId: 'en-US').toList();

      expect(progress, [
        const ModelInstallProgress(fraction: 0.4, done: false),
        const ModelInstallProgress(fraction: 1, done: true),
      ]);
    });

    test('completion on done cancels the native subscription', () async {
      var cancelled = false;
      messenger.setMockStreamHandler(
        modelEvents,
        MockStreamHandler.inline(
          onListen: (arguments, sink) {
            sink.success({'fraction': 1.0, 'done': true});
          },
          onCancel: (arguments) => cancelled = true,
        ),
      );

      await engine.installModel(localeId: 'en-US').toList();

      expect(cancelled, isTrue);
    });

    test('a raw stream error maps through the taxonomy', () async {
      messenger.setMockStreamHandler(
        modelEvents,
        MockStreamHandler.inline(
          onListen: (arguments, sink) {
            sink.error(code: 'model_install_failed', message: 'offline');
          },
        ),
      );

      await expectLater(
        engine.installModel(localeId: 'en-US').toList(),
        throwsA(isA<ModelInstallFailed>()),
      );
    });

    test('an install error payload becomes ModelInstallFailed', () async {
      messenger.setMockStreamHandler(
        modelEvents,
        MockStreamHandler.inline(
          onListen: (arguments, sink) {
            sink.success({'type': 'error', 'code': 'model_install_failed', 'message': 'offline'});
          },
        ),
      );

      await expectLater(
        engine.installModel(localeId: 'en-US').toList(),
        throwsA(isA<ModelInstallFailed>()),
      );
    });

    test('overlapping installs serialize; the second waits for the first teardown', () async {
      final listens = <String>[];
      messenger.setMockStreamHandler(
        modelEvents,
        MockStreamHandler.inline(
          onListen: (arguments, sink) {
            final tag = (arguments as Map?)?['localeId'] as String;
            listens.add(tag);
            if (tag == 'a') {
              sink.success({'fraction': 0.5, 'done': false}); // never completes
            } else {
              sink.success({'fraction': 1.0, 'done': true});
            }
          },
        ),
      );

      final firstEvents = <ModelInstallProgress>[];
      final first = engine.installModel(localeId: 'a').listen(firstEvents.add);
      final second = engine.installModel(localeId: 'b').toList();
      await Future<void>.delayed(Duration.zero);

      expect(listens, ['a']);
      expect(firstEvents, [const ModelInstallProgress(fraction: 0.5, done: false)]);

      await first.cancel();
      expect(await second, [const ModelInstallProgress(fraction: 1, done: true)]);
      expect(listens, ['a', 'b']);
    });

    test('structured payload keys ride into the typed exceptions', () async {
      messenger.setMockStreamHandler(
        modelEvents,
        MockStreamHandler.inline(
          onListen: (arguments, sink) {
            sink.success({
              'type': 'error',
              'code': 'model_install_failed',
              'message': 'stuck',
              'status': 'downloading',
            });
          },
        ),
      );
      await expectLater(
        engine.installModel(localeId: 'ru-RU').toList(),
        throwsA(
          isA<ModelInstallFailed>().having(
            (e) => e.assetStatus,
            'assetStatus',
            ModelAssetStatus.downloading,
          ),
        ),
      );

      messenger.setMockStreamHandler(
        modelEvents,
        MockStreamHandler.inline(
          onListen: (arguments, sink) {
            sink.success({
              'type': 'error',
              'code': 'reservation_cap',
              'message': 'full',
              'reservedTags': ['de-DE', 'en-US'],
            });
          },
        ),
      );
      await expectLater(
        engine.installModel(localeId: 'fr-FR').toList(),
        throwsA(
          isA<ReservationCapReached>().having((e) => e.reservedTags, 'reservedTags', [
            'de-DE',
            'en-US',
          ]),
        ),
      );
    });
  });
}
