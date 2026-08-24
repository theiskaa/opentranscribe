import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/src/transcribe/apple_speech_engines.dart';
import 'package:transcriber/src/transcribe/transcription_engine.dart';

/// Pins the engine-routing half of the channel contract with SpeechEngine.swift:
/// which calls carry the engine argument, and with which spelling.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const methods = MethodChannel('transcriber/speech');
  const events = EventChannel('transcriber/speech/events');
  const modelEvents = EventChannel('transcriber/speech/model');

  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    messenger.setMockMethodCallHandler(methods, (call) async {
      calls.add(call);
      return switch (call.method) {
        'supportedLocales' || 'installedLocales' => <String>[],
        'checkAvailability' => {'status': 'available'},
        'isModelInstalled' || 'removeLanguage' => false,
        'localeStatus' => {'status': 'supported', 'reserved': false, 'resolvedTag': 'en-US'},
        'reservationInfo' => {'max': 5, 'reserved': <String>[]},
        'transcribeFile' => {'text': '', 'segments': <Object?>[]},
        'analyzerAvailable' => true,
        _ => null,
      };
    });
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(methods, null);
    messenger.setMockStreamHandler(events, null);
    messenger.setMockStreamHandler(modelEvents, null);
  });

  test('apple speech stamps analyzer on every engine-answering call', () async {
    final engine = AppleSpeechEngine();
    await engine.checkAvailability(localeId: 'en-US');
    await engine.supportedLocales();
    await engine.isModelInstalled(localeId: 'en-US');
    await engine.installedLocales();
    await engine.localeStatus(localeId: 'en-US');
    await engine.removeLanguage(localeId: 'en-US');
    await engine.reservationInfo();
    await engine.transcribeFile(File('/tmp/a.m4a'), localeId: 'en-US');

    expect(calls, hasLength(8));
    for (final call in calls) {
      expect((call.arguments as Map)['engine'], 'analyzer', reason: call.method);
    }
  });

  test('apple dictation stamps classic on every engine-answering call', () async {
    final engine = AppleDictationEngine();
    await engine.checkAvailability(localeId: 'en-US');
    await engine.supportedLocales();
    await engine.transcribeFile(File('/tmp/a.m4a'), localeId: 'en-US');

    expect(calls, hasLength(3));
    for (final call in calls) {
      expect((call.arguments as Map)['engine'], 'classic', reason: call.method);
    }
  });

  test('a live session stamps its engine on startLive and none on stopLive', () async {
    final sub = AppleDictationEngine().transcribeLive(localeId: 'en-US').listen((_) {});
    await pumpEventQueue();
    await sub.cancel();
    await pumpEventQueue();

    final startLive = calls.singleWhere((call) => call.method == 'startLive');
    expect((startLive.arguments as Map)['engine'], 'classic');
    final stopLive = calls.singleWhere((call) => call.method == 'stopLive');
    expect((stopLive.arguments as Map).containsKey('engine'), isFalse);
  });

  test('cancelBatches carries no engine because it abandons both', () async {
    await AppleSpeechEngine().cancelBatches();

    expect(calls.single.method, 'cancelBatches');
    expect(calls.single.arguments, isNull);
  });

  test('the install stream listens with the analyzer engine', () async {
    Object? listenArgs;
    messenger.setMockStreamHandler(
      modelEvents,
      MockStreamHandler.inline(
        onListen: (arguments, sink) {
          listenArgs = arguments;
          sink.success({'fraction': 1.0, 'done': true});
          sink.endOfStream();
        },
      ),
    );

    await AppleSpeechEngine().installModel(localeId: 'en-US').drain<void>();

    expect((listenArgs! as Map)['engine'], 'analyzer');
  });

  test('dictation localeReady follows the classic locale status', () async {
    expect(await AppleDictationEngine().localeReady(localeId: 'en-US'), isFalse);

    messenger.setMockMethodCallHandler(methods, (call) async {
      calls.add(call);
      return {'status': 'installed', 'reserved': true, 'resolvedTag': 'en-US'};
    });
    expect(await AppleDictationEngine().localeReady(localeId: 'en-US'), isTrue);

    final statusCalls = calls.where((call) => call.method == 'localeStatus');
    expect(statusCalls, hasLength(2));
    for (final call in statusCalls) {
      expect((call.arguments as Map)['engine'], 'classic');
    }
  });

  test('dictation transcripts carry the apple.dictation engine id', () async {
    final transcript = await AppleDictationEngine().transcribeFile(
      File('/tmp/a.m4a'),
      localeId: 'en-US',
    );

    expect(transcript.engineId, 'apple.dictation');
  });

  test('apple dictation manages no models but streams and cancels', () {
    final engine = AppleDictationEngine();

    expect(engine, isNot(isA<ManagedModelEngine>()));
    expect(engine, isA<StreamingTranscriptionEngine>());
    expect(engine, isA<CancellableBatchEngine>());
    expect(engine.onDeviceOnly, isTrue);
  });

  test('analyzerAvailable answers the native probe', () async {
    expect(await AppleSpeechEngine().analyzerAvailable(), isTrue);
  });

  test('analyzerAvailable folds channel failures to unavailable', () async {
    messenger.setMockMethodCallHandler(methods, (call) async {
      throw PlatformException(code: 'boom');
    });

    expect(await AppleSpeechEngine().analyzerAvailable(), isFalse);
  });

  test('analyzerAvailable folds a missing plugin to unavailable', () async {
    messenger.setMockMethodCallHandler(methods, null);

    expect(await AppleSpeechEngine().analyzerAvailable(), isFalse);
  });

  test('two engines over one transport mint unique sessions and both stream', () async {
    MockStreamHandlerEventSink? liveSink;
    messenger.setMockStreamHandler(
      events,
      MockStreamHandler.inline(onListen: (arguments, sink) => liveSink = sink),
    );
    final live = SpeechLiveTransport();
    final speechTexts = <String>[];
    final dictationTexts = <String>[];
    final speech = AppleSpeechEngine(
      live: live,
    ).transcribeLive(localeId: 'en-US').listen((event) => speechTexts.add(event.text));
    final dictation = AppleDictationEngine(
      live: live,
    ).transcribeLive(localeId: 'en-US').listen((event) => dictationTexts.add(event.text));
    await pumpEventQueue();

    final sessions = [
      for (final call in calls)
        if (call.method == 'startLive') (call.arguments as Map)['session'] as int,
    ];
    expect(sessions, hasLength(2));
    expect(sessions.toSet(), hasLength(2));
    liveSink!.success({'session': sessions[0], 'text': 'from speech', 'isFinal': false});
    liveSink!.success({'session': sessions[1], 'text': 'from dictation', 'isFinal': false});
    await pumpEventQueue();

    expect(speechTexts, ['from speech']);
    expect(dictationTexts, ['from dictation']);

    await speech.cancel();
    await dictation.cancel();
  });
}
