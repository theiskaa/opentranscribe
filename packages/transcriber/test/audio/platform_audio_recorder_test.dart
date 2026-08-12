import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/src/audio/platform_audio_recorder.dart';
import 'package:transcriber/src/audio/recording.dart';
import 'package:transcriber/src/transcribe/transcription_exception.dart';

/// Pins the channel contract with AudioCapture.swift: payload shapes, status
/// strings, error mapping, and the Dart-side replay cache.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const methods = MethodChannel('opentranscribe/audio');
  const statusEvents = EventChannel('opentranscribe/audio/status');
  const levelEvents = EventChannel('opentranscribe/audio/level');

  late PlatformAudioRecorder recorder;

  setUp(() {
    recorder = PlatformAudioRecorder();
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(methods, null);
    messenger.setMockStreamHandler(statusEvents, null);
    messenger.setMockStreamHandler(levelEvents, null);
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
          sink.success('paused');
          sink.success('interrupted');
          sink.success('stopped');
        },
      ),
    );

    final statuses = await recorder.status.take(4).toList();

    expect(statuses, [
      CaptureStatus.recording,
      CaptureStatus.paused,
      CaptureStatus.interrupted,
      CaptureStatus.stopped,
    ]);
  });

  test('pause, resume, and cancel invoke their methods and map errors', () async {
    final called = <String>[];
    mockMethods((call) async {
      called.add(call.method);
      return null;
    });

    await recorder.pause();
    await recorder.resume();
    await recorder.cancel();
    expect(called, ['pause', 'resume', 'cancel']);

    mockMethods(
      (call) async => throw PlatformException(code: 'not_paused', message: 'capture not paused'),
    );
    await expectLater(
      recorder.resume(),
      throwsA(isA<CaptureFailed>().having((e) => e.code, 'code', 'not_paused')),
    );
  });

  test('level decodes doubles from its channel', () async {
    messenger.setMockStreamHandler(
      levelEvents,
      MockStreamHandler.inline(
        onListen: (arguments, sink) {
          sink.success(0.0);
          sink.success(0.42);
          sink.success(1);
        },
      ),
    );

    final levels = await recorder.level.take(3).toList();

    expect(levels, [0.0, 0.42, 1.0]);
  });

  test('a terminal status is not replayed to the next listener', () async {
    // Emit only on the first native listen: native replays nothing terminal,
    // so a re-listen must be served purely from the Dart cache under test.
    var firstListen = true;
    messenger.setMockStreamHandler(
      statusEvents,
      MockStreamHandler.inline(
        onListen: (arguments, sink) {
          if (!firstListen) return;
          firstListen = false;
          sink.success('recording');
          sink.success('interrupted');
        },
      ),
    );

    // Drive the pipeline so the terminal event lands and clears the cache.
    final first = recorder.status.take(2).toList();
    await first;

    // A fresh listener must not see the dead session's interruption: replaying
    // it would auto-finalize the next recording the instant it starts.
    var replayed = false;
    final sub = recorder.status.listen((_) => replayed = true);
    await Future<void>.delayed(Duration.zero);
    expect(replayed, isFalse);

    await sub.cancel();
  });

  test('two concurrent level listeners share one pipeline', () async {
    var listens = 0;
    messenger.setMockStreamHandler(
      levelEvents,
      MockStreamHandler.inline(
        onListen: (arguments, sink) {
          listens += 1;
          sink.success(0.5);
        },
      ),
    );

    final a = <double>[];
    final b = <double>[];
    final subA = recorder.level.listen(a.add);
    final subB = recorder.level.listen(b.add);
    await Future<void>.delayed(Duration.zero);

    // One native subscription; cancelling one listener must not kill the other.
    expect(listens, 1);
    await subA.cancel();
    expect(a, isNotEmpty);

    await subB.cancel();
  });

  test('a paused status replays to a second listener via the cache', () async {
    messenger.setMockStreamHandler(
      statusEvents,
      MockStreamHandler.inline(
        onListen: (arguments, sink) {
          sink.success('paused');
        },
      ),
    );

    final first = recorder.status.listen((_) {});
    await Future<void>.delayed(Duration.zero);

    final replayed = await recorder.status.first.timeout(const Duration(seconds: 1));
    expect(replayed, CaptureStatus.paused);

    await first.cancel();
  });

  test('an explicit stop clears the cached status so a fresh listener gets no replay', () async {
    // Native replays 'recording' only while still capturing (the real
    // AudioRecorderPlugin.onListen gates on isCapturing): fire it once, on the
    // first native listen, never again once stop() has ended the session.
    var firstListen = true;
    messenger.setMockStreamHandler(
      statusEvents,
      MockStreamHandler.inline(
        onListen: (arguments, sink) {
          if (!firstListen) return;
          firstListen = false;
          sink.success('recording');
        },
      ),
    );
    mockMethods((call) async => {'name': 'otr-x.m4a', 'durationMs': 100});

    final first = recorder.status.listen((_) {});
    await Future<void>.delayed(Duration.zero);
    await first.cancel();

    await recorder.stop();

    var replayed = false;
    final second = recorder.status.listen((_) => replayed = true);
    await Future<void>.delayed(Duration.zero);
    expect(replayed, isFalse);

    await second.cancel();
  });

  test('an explicit cancel clears the cached status so a fresh listener gets no replay', () async {
    var firstListen = true;
    messenger.setMockStreamHandler(
      statusEvents,
      MockStreamHandler.inline(
        onListen: (arguments, sink) {
          if (!firstListen) return;
          firstListen = false;
          sink.success('recording');
        },
      ),
    );
    mockMethods((call) async => null);

    final first = recorder.status.listen((_) {});
    await Future<void>.delayed(Duration.zero);
    await first.cancel();

    await recorder.cancel();

    var replayed = false;
    final second = recorder.status.listen((_) => replayed = true);
    await Future<void>.delayed(Duration.zero);
    expect(replayed, isFalse);

    await second.cancel();
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
