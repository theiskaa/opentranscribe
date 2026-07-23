import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/audio/platform_audio_recorder.dart';
import 'package:opentranscribe/core/audio/recording.dart';
import 'package:opentranscribe/core/transcribe/transcription_exception.dart';

/// Pins the channel contract with AudioCapture.swift: payload shapes, status
/// strings, error mapping, and the Dart-side replay cache.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const methods = MethodChannel('opentranscribe/audio');
  const statusEvents = EventChannel('opentranscribe/audio/status');

  late PlatformAudioRecorder recorder;

  setUp(() {
    recorder = PlatformAudioRecorder();
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(methods, null);
    messenger.setMockStreamHandler(statusEvents, null);
  });

  void mockMethods(Future<Object?> Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(methods, handler);
  }

  test('stop decodes the name key into Recording.path', () async {
    mockMethods((call) async {
      expect(call.method, 'stop');
      return {'name': 'otr-abc.m4a', 'durationMs': 1500};
    });

    final recording = await recorder.stop();

    expect(recording, const Recording(path: 'otr-abc.m4a', duration: Duration(milliseconds: 1500)));
  });

  test('permission strings map to the enum', () async {
    Future<PermissionStatus> statusFor(String raw) async {
      mockMethods((call) async => raw);
      return recorder.ensurePermission();
    }

    expect(await statusFor('granted'), PermissionStatus.granted);
    expect(await statusFor('denied'), PermissionStatus.denied);
    expect(await statusFor('restricted'), PermissionStatus.restricted);
    expect(await statusFor('bogus'), PermissionStatus.undetermined);
  });

  test('a channel error maps to CaptureFailed carrying the native code', () async {
    mockMethods((call) async => throw PlatformException(code: 'no_input', message: 'no mic'));

    await expectLater(
      recorder.start(),
      throwsA(
        isA<CaptureFailed>()
            .having((e) => e.code, 'code', 'no_input')
            .having((e) => e.message, 'message', 'no mic'),
      ),
    );
  });

  test('probeRecording maps durationMs, null for unreadable', () async {
    mockMethods((call) async {
      expect(call.method, 'probeAudio');
      return (call.arguments as Map)['name'] == 'good.m4a' ? 3000 : null;
    });

    expect(await recorder.probeRecording('good.m4a'), const Duration(seconds: 3));
    expect(await recorder.probeRecording('bad.m4a'), isNull);
  });

  test('status maps the lifecycle strings and drops unknown ones', () async {
    messenger.setMockStreamHandler(
      statusEvents,
      MockStreamHandler.inline(
        onListen: (arguments, sink) {
          sink.success('recording');
          sink.success('mystery');
          sink.success('interrupted');
          sink.success('stopped');
        },
      ),
    );

    final statuses = await recorder.status.take(3).toList();

    expect(statuses, [CaptureStatus.recording, CaptureStatus.interrupted, CaptureStatus.stopped]);
  });

  test('a second concurrent listener receives the cached current state', () async {
    messenger.setMockStreamHandler(
      statusEvents,
      MockStreamHandler.inline(
        onListen: (arguments, sink) {
          sink.success('recording');
        },
      ),
    );

    // First listener drives the native subscription and caches 'recording'.
    final first = recorder.status.listen((_) {});
    await Future<void>.delayed(Duration.zero);

    // Native replays only on the 0->1 transition; the Dart cache must cover this
    // second listener, per the AudioRecorder.status contract.
    final replayed = await recorder.status.first.timeout(const Duration(seconds: 1));
    expect(replayed, CaptureStatus.recording);

    await first.cancel();
  });
}
