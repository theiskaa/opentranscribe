import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/transcribe/apple_speech_engine.dart';
import 'package:opentranscribe/core/transcribe/transcript.dart';
import 'package:opentranscribe/core/transcribe/transcript_event.dart';
import 'package:opentranscribe/core/transcribe/transcription_engine.dart';
import 'package:opentranscribe/core/transcribe/transcription_exception.dart';

/// Pins the channel contract with SpeechEngine.swift: payload shapes, error codes,
/// and stream completion semantics. This is where native/Dart drift would surface.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const methods = MethodChannel('opentranscribe/speech');
  const events = EventChannel('opentranscribe/speech/events');
  const modelEvents = EventChannel('opentranscribe/speech/model');
  final fixedClock = DateTime.utc(2026, 3, 4, 12);

  late AppleSpeechEngine engine;

  setUp(() {
    engine = AppleSpeechEngine(clock: () => fixedClock);
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
      await expectCode('file_missing', isA<TranscriptionFailed>());
      await expectCode('transcribe_error', isA<TranscriptionFailed>());
      await expectCode('bad_args', isA<TranscriptionFailed>());
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
    // No handlers registered at all: every method must stay inside its contract
    // rather than leaking a raw MissingPluginException.
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

  group('transcribeLive', () {
    test('yields partials then completes on the final event', () async {
      messenger.setMockStreamHandler(
        events,
        MockStreamHandler.inline(
          onListen: (arguments, sink) {
            expect((arguments as Map?)?['localeId'], 'en-US');
            sink.success({'text': 'hel', 'isFinal': false});
            sink.success({
              'text': 'hello',
              'isFinal': true,
              'segments': [
                {'text': 'hello', 'startMs': 0, 'endMs': 700},
              ],
            });
          },
        ),
      );

      final received = await engine.transcribeLive(localeId: 'en-US').toList();

      expect(received, [
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
      messenger.setMockStreamHandler(
        events,
        MockStreamHandler.inline(
          onListen: (arguments, sink) {
            sink.success({'type': 'error', 'code': 'permission_denied', 'message': 'no'});
          },
        ),
      );

      await expectLater(
        engine.transcribeLive(localeId: 'en-US').toList(),
        throwsA(isA<PermissionDenied>()),
      );
    });

    test('non-map junk events are skipped, and the final event cancels natively', () async {
      // The return-on-isFinal cancelling the native subscription is the load-bearing
      // cleanup (it drives native onCancel -> stopLive); pin it.
      var cancelled = false;
      messenger.setMockStreamHandler(
        events,
        MockStreamHandler.inline(
          onListen: (arguments, sink) {
            sink.success('junk');
            sink.success({'text': 'done', 'isFinal': true});
          },
          onCancel: (arguments) => cancelled = true,
        ),
      );

      final received = await engine.transcribeLive(localeId: 'en-US').toList();

      expect(received, [const TranscriptEvent(text: 'done', isFinal: true)]);
      expect(cancelled, isTrue);
    });

    test('a raw stream error (not an error payload) maps through the taxonomy', () async {
      messenger.setMockStreamHandler(
        events,
        MockStreamHandler.inline(
          onListen: (arguments, sink) {
            sink.error(code: 'on_device_unavailable', message: 'no model');
          },
        ),
      );

      await expectLater(
        engine.transcribeLive(localeId: 'en-US').toList(),
        throwsA(isA<OnDeviceUnavailable>()),
      );
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
      // Cancelling drives native onCancel -> install-task teardown; pin it like the
      // live stream's cleanup.
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
  });
}
