import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/src/audio/fake_audio_activity.dart';
import 'package:transcriber/src/transcribe/transcription_engine.dart';
import 'package:transcriber/src/transcribe/transcription_exception.dart';
import 'package:transcriber/src/whisper/fake_model_fetcher.dart';
import 'package:transcriber/src/whisper/fake_pcm_decoder.dart';
import 'package:transcriber/src/whisper/fake_whisper_runtime.dart';
import 'package:transcriber/src/whisper/model_fetcher.dart';
import 'package:transcriber/src/whisper/whisper_catalog.dart';
import 'package:transcriber/src/whisper/whisper_engine.dart';
import 'package:transcriber/src/whisper/whisper_runtime.dart';

import 'zip_fixture.dart';

void main() {
  late Directory root;
  late Directory models;
  late FakeModelFetcher fetcher;
  late FakePcmDecoder decoder;
  late FakeWhisperRuntime runtime;
  final audio = File('/recordings/otr-a.m4a');

  setUp(() async {
    root = await Directory.systemTemp.createTemp('otr-whisper-');
    models = Directory('${root.path}/models');
    fetcher = FakeModelFetcher();
    decoder = FakePcmDecoder(scratch: Directory('${root.path}/scratch'));
    runtime = FakeWhisperRuntime();
  });
  tearDown(() async => root.delete(recursive: true));

  WhisperEngine engine() => WhisperEngine(
    modelsDir: models,
    fetcher: fetcher,
    decoder: decoder,
    runtime: runtime,
    clock: () => DateTime.utc(2026, 9, 6),
  );

  Future<void> install(WhisperEngine e, [String? id]) =>
      e.installModelById(id ?? e.selectedModelId).drain<void>();

  File fileOf(String id) => File('${models.path}/${whisperModelById(id)!.fileName}');

  Future<void> until(bool Function() condition) async {
    final deadline = DateTime.now().add(const Duration(seconds: 2));
    while (!condition()) {
      if (DateTime.now().isAfter(deadline)) fail('condition never held');
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
  }

  group('identity and languages', () {
    test('the engine is on-device and lists the languages the selected model carries', () async {
      final e = engine();

      expect(e.id, 'whisper.cpp');
      expect(e.onDeviceOnly, isTrue);
      expect(await e.supportedLocales(), hasLength(99));
      expect(await e.supportedLocales(), contains('ka-GE'));
      expect(await e.supportedLocales(), isNot(contains('yue-HK')));

      await e.selectModel('large-v3-turbo-q5_0');
      expect(await e.supportedLocales(), hasLength(100));
      expect(await e.supportedLocales(), contains('yue-HK'));
    });

    test('Cantonese is refused on a model without its token, never sent as another', () async {
      final e = engine();
      await install(e);

      expect((await e.checkAvailability(localeId: 'yue-HK')).isAvailable, isFalse);
      expect((await e.localeStatus(localeId: 'yue-HK')).status, ModelAssetStatus.unsupported);
      await expectLater(
        e.transcribeFile(audio, localeId: 'yue-HK'),
        throwsA(isA<OnDeviceUnavailable>()),
      );
      expect(runtime.runs, isEmpty);
    });

    test('an unknown language is unavailable and a known one available in any region', () async {
      final e = engine();

      expect((await e.checkAvailability(localeId: 'xx-XX')).isAvailable, isFalse);
      expect((await e.checkAvailability(localeId: 'de-AT')).isAvailable, isTrue);
    });

    test('a transcription in an unknown language refuses before touching audio', () async {
      final e = engine();

      await expectLater(
        e.transcribeFile(audio, localeId: 'xx-XX'),
        throwsA(isA<OnDeviceUnavailable>()),
      );
      expect(decoder.calls, isEmpty);
      expect(fetcher.calls, isEmpty);
    });
  });

  group('transcribing', () {
    test('the first run deletes the decoded slices a killed process left behind', () async {
      final scratch = Directory('${root.path}/scratch')..createSync(recursive: true);
      final leftover = File('${scratch.path}/otr-left.pcm')..writeAsBytesSync([1, 2, 3]);
      final unrelated = File('${scratch.path}/notes.txt')..writeAsStringSync('keep');
      final e = engine();
      await install(e);

      await e.transcribeFile(audio, localeId: 'en-US');

      expect(leftover.existsSync(), isFalse);
      expect(unrelated.existsSync(), isTrue);
    });

    test('a run hands the decoder the slice and whisper the lowercase code', () async {
      final e = engine();
      await install(e);

      final transcript = await e.transcribeFile(
        audio,
        localeId: 'DE-at',
        start: const Duration(seconds: 1),
        end: const Duration(seconds: 3),
      );

      expect(decoder.calls.single.start, const Duration(seconds: 1));
      expect(decoder.calls.single.end, const Duration(seconds: 3));
      expect(runtime.runs.single.language, 'de');
      expect(runtime.runs.single.pcmPath, decoder.written.single.path);
      expect(transcript.localeId, 'DE-at');
      expect(transcript.engineId, 'whisper.cpp');
      expect(transcript.fullText, 'hello');
    });

    test('segments keep their timing and confidence, trimmed and joined by spaces', () async {
      runtime.segments = const [
        WhisperSegment(
          text: ' Hello there. ',
          start: Duration.zero,
          end: Duration(milliseconds: 1500),
          confidence: 0.8,
        ),
        WhisperSegment(
          text: '   ',
          start: Duration(milliseconds: 1500),
          end: Duration(milliseconds: 1600),
          confidence: 0.1,
        ),
        WhisperSegment(
          text: 'Second.',
          start: Duration(milliseconds: 1600),
          end: Duration(seconds: 3),
          confidence: 0.6,
        ),
      ];
      final e = engine();
      await install(e);

      final transcript = await e.transcribeFile(audio, localeId: 'en-US');

      expect(transcript.fullText, 'Hello there. Second.');
      expect(transcript.segments, hasLength(2));
      expect(transcript.segments.first.end, const Duration(milliseconds: 1500));
      expect(transcript.segments.first.confidence, 0.8);
      expect(transcript.segments.last.start, const Duration(milliseconds: 1600));
    });

    test('a run that heard nothing is an empty transcript, not a failure', () async {
      runtime.segments = const [];
      final e = engine();
      await install(e);

      final transcript = await e.transcribeFile(audio, localeId: 'en-US');

      expect(transcript.isEmpty, isTrue);
      expect(transcript.segments, isEmpty);
    });

    test('a slice holding no audio is an empty transcript, not a failure', () async {
      final e = engine();
      await install(e);

      final transcript = await e.transcribeFile(
        audio,
        localeId: 'en-US',
        start: const Duration(seconds: 3),
        end: const Duration(seconds: 3),
      );

      expect(transcript.isEmpty, isTrue);
      expect(runtime.runs, isEmpty);
    });

    test('a model missing at run time installs first, the managed-engine convention', () async {
      final e = engine();

      await e.transcribeFile(audio, localeId: 'en-US');

      expect(fetcher.calls.single.into.path, fileOf(whisperDefaultModelId).path);
      expect(runtime.loads.single, fileOf(whisperDefaultModelId).path);
      expect(runtime.runs, hasLength(1));
    });

    test('a cancel during a first-use install stops the download and the run', () async {
      final gate = Completer<void>();
      fetcher = FakeModelFetcher(gate: gate.future);
      final e = engine();

      final run = e.transcribeFile(audio, localeId: 'en-US');
      await until(() => fetcher.calls.isNotEmpty);
      await e.cancelBatches();
      gate.complete();

      await expectLater(run, throwsA(isA<TranscriptionFailed>()));
      expect(fetcher.cancelled, 1);
      expect(runtime.runs, isEmpty);
    });

    test('a reporting run forwards the runtime\'s fractions in order', () async {
      final e = engine();
      await install(e);
      runtime.progressSteps = [0.3, 0.9];
      final heard = <double>[];

      await e.transcribeFileWithProgress(audio, localeId: 'en-US', onProgress: heard.add);

      expect(heard, [0.3, 0.9]);
    });

    test('a plain run asks the runtime for no progress', () async {
      final e = engine();
      await install(e);
      runtime.progressSteps = [0.3, 0.9];
      var asked = false;
      runtime.onProgressAsked = () => asked = true;

      await e.transcribeFile(audio, localeId: 'en-US');

      expect(asked, isFalse);
    });

    test('a landed run deletes its scratch file', () async {
      final e = engine();
      await install(e);

      await e.transcribeFile(audio, localeId: 'en-US');

      expect(decoder.written.single.existsSync(), isFalse);
    });

    test(
      'a missing recording is RecordingMissing and other decode failures TranscriptionFailed',
      () async {
        final e = engine();
        await install(e);

        decoder.throwOnDecode = 'decode_missing';
        await expectLater(
          e.transcribeFile(audio, localeId: 'en-US'),
          throwsA(isA<RecordingMissing>()),
        );
        decoder.throwOnDecode = 'decode_unreadable';
        await expectLater(
          e.transcribeFile(audio, localeId: 'en-US'),
          throwsA(isA<TranscriptionFailed>()),
        );
        expect(runtime.runs, isEmpty);
      },
    );

    test('a failed run still deletes its scratch file', () async {
      runtime.failRun = true;
      final e = engine();
      await install(e);

      await expectLater(
        e.transcribeFile(audio, localeId: 'en-US'),
        throwsA(isA<TranscriptionFailed>()),
      );

      expect(decoder.written.single.existsSync(), isFalse);
    });

    test(
      'a model that fails to load says it would not open, names itself, and keeps its file',
      () async {
        runtime.failLoad = true;
        final e = engine();
        await install(e);

        await expectLater(
          e.transcribeFile(audio, localeId: 'en-US'),
          throwsA(
            isA<ModelInstallFailed>()
                .having((f) => f.reason, 'reason', ModelInstallReason.loadFailed)
                .having((f) => f.modelId, 'modelId', whisperDefaultModelId),
          ),
        );
        expect(fileOf(whisperDefaultModelId).existsSync(), isTrue);
      },
    );

    test('the session loads once per model and reloads when the choice changes', () async {
      final e = engine();
      await install(e);
      await install(e, 'tiny-q5_1');

      await e.transcribeFile(audio, localeId: 'en-US');
      await e.transcribeFile(audio, localeId: 'fr-FR');
      await e.selectModel('tiny-q5_1');
      await e.transcribeFile(audio, localeId: 'en-US');

      expect(runtime.loads, [fileOf(whisperDefaultModelId).path, fileOf('tiny-q5_1').path]);
      expect(runtime.closes, 1);
      expect(runtime.runs.last.modelPath, fileOf('tiny-q5_1').path);
    });

    test('runs are serialized so a second call waits for the first', () async {
      final gate = Completer<void>();
      runtime.gate = gate.future;
      final e = engine();
      await install(e);

      final first = e.transcribeFile(audio, localeId: 'en-US');
      final second = e.transcribeFile(audio, localeId: 'en-US');
      await until(() => runtime.runs.isNotEmpty);
      await pumpEventQueue();
      expect(runtime.runs, hasLength(1));

      runtime.gate = null;
      gate.complete();
      await first;
      await second;
      expect(runtime.runs, hasLength(2));
    });

    test('a cancel aborts the run in flight and drops the queued ones', () async {
      final gate = Completer<void>();
      runtime.gate = gate.future;
      final e = engine();
      await install(e);

      final first = e.transcribeFile(audio, localeId: 'en-US');
      final queued = e.transcribeFile(audio, localeId: 'en-US');
      await until(() => runtime.runs.isNotEmpty);
      await e.cancelBatches();
      gate.complete();

      final cancelled = isA<TranscriptionFailed>().having((f) => f.message, 'message', 'cancelled');
      await expectLater(first, throwsA(cancelled));
      await expectLater(queued, throwsA(cancelled));
      expect(runtime.aborts, 1);
      expect(runtime.runs, hasLength(1));
      expect(decoder.written.single.existsSync(), isFalse);
    });

    test('a cancel while the recording is measured decodes nothing', () async {
      final gate = Completer<void>();
      decoder.lengthGate = gate.future;
      final e = engine();
      await install(e);

      final run = e.transcribeFile(audio, localeId: 'en-US');
      await pumpEventQueue();
      await e.cancelBatches();
      gate.complete();

      await expectLater(run, throwsA(isA<TranscriptionFailed>()));
      expect(decoder.calls, isEmpty);
      expect(runtime.loads, isEmpty);
    });

    test('a cancel with nothing in flight is harmless and later runs land', () async {
      final e = engine();
      await install(e);

      await e.cancelBatches();
      final transcript = await e.transcribeFile(audio, localeId: 'en-US');

      expect(transcript.fullText, 'hello');
    });

    test('the batch budget grows with the audio by the selected model\'s factor', () async {
      final e = engine();

      expect(e.batchBudget(const Duration(minutes: 10)), const Duration(minutes: 32));
      await e.selectModel('large-v3-turbo-q5_0');
      expect(e.batchBudget(const Duration(minutes: 10)), const Duration(minutes: 62));
    });
  });

  group('long audio', () {
    const minute = Duration(minutes: 1);
    const cut = [
      WhisperSegment(
        text: 'whole',
        start: Duration.zero,
        end: Duration(minutes: 8),
        confidence: 0.9,
      ),
      WhisperSegment(
        text: 'cut',
        start: Duration(minutes: 9),
        end: Duration(minutes: 10),
        confidence: 0.5,
      ),
    ];

    WhisperEngine longEngine(Duration length) {
      decoder = FakePcmDecoder(
        scratch: Directory('${root.path}/scratch'),
        fileDuration: length,
        framesPerSecond: 4,
      );
      return engine();
    }

    List<(Duration?, Duration?)> slices() => [for (final c in decoder.calls) (c.start, c.end)];

    test('a file longer than a chunk runs as slices, one scratch file alive at a time', () async {
      runtime.segments = const [];
      final e = longEngine(minute * 25);
      await install(e);
      var gate = Completer<void>();
      runtime.gate = gate.future;

      final run = e.transcribeFile(audio, localeId: 'en-US');
      await until(() => runtime.runs.length == 1);
      final first = gate;
      gate = Completer<void>();
      runtime.gate = gate.future;
      first.complete();
      await until(() => runtime.runs.length == 2);
      expect(decoder.written[0].existsSync(), isFalse);
      expect(decoder.written[1].existsSync(), isTrue);
      runtime.gate = null;
      gate.complete();
      await run;

      expect(slices(), [
        (minute * 0, minute * 10),
        (minute * 10, minute * 20),
        (minute * 20, minute * 25),
      ]);
      expect(decoder.written.any((f) => f.existsSync()), isFalse);
    });

    test('a segment cut by a chunk boundary is dropped and heard whole from its start', () async {
      runtime.segments = cut;
      final e = longEngine(minute * 25);
      await install(e);

      final transcript = await e.transcribeFile(audio, localeId: 'en-US');

      expect(slices(), [
        (minute * 0, minute * 10),
        (minute * 9, minute * 19),
        (minute * 18, minute * 25),
      ]);
      expect(transcript.segments.map((s) => s.text), ['whole', 'whole', 'whole']);
      expect(transcript.segments.map((s) => s.start), [Duration.zero, minute * 9, minute * 18]);
      expect(transcript.segments[1].end, minute * 17);
    });

    test('a chunk whose only segment starts at its own start advances a whole chunk', () async {
      runtime.segments = const [
        WhisperSegment(
          text: 'one',
          start: Duration.zero,
          end: Duration(minutes: 10),
          confidence: 1,
        ),
      ];
      final e = longEngine(minute * 25);
      await install(e);

      await e.transcribeFile(audio, localeId: 'en-US');

      expect(slices(), [
        (minute * 0, minute * 10),
        (minute * 10, minute * 20),
        (minute * 20, minute * 25),
      ]);
    });

    test('a last segment that ended well before the boundary is kept, not heard again', () async {
      runtime.segments = const [
        WhisperSegment(
          text: 'early',
          start: Duration(minutes: 1),
          end: Duration(minutes: 1, seconds: 5),
          confidence: 1,
        ),
      ];
      final e = longEngine(minute * 25);
      await install(e);

      final transcript = await e.transcribeFile(audio, localeId: 'en-US');

      expect(slices(), [
        (minute * 0, minute * 10),
        (minute * 10, minute * 20),
        (minute * 20, minute * 25),
      ]);
      expect(transcript.segments.map((s) => s.start), [minute, minute * 11, minute * 21]);
    });

    test('a last segment ending just inside the margin is heard again from its start', () async {
      runtime.segments = const [
        WhisperSegment(
          text: 'near',
          start: Duration(minutes: 9),
          end: Duration(minutes: 9, seconds: 59),
          confidence: 1,
        ),
      ];
      final e = longEngine(minute * 25);
      await install(e);

      await e.transcribeFile(audio, localeId: 'en-US');

      expect(slices().take(2), [(minute * 0, minute * 10), (minute * 9, minute * 19)]);
    });

    test('a last segment ending just before the margin is kept where it is', () async {
      runtime.segments = const [
        WhisperSegment(
          text: 'clear',
          start: Duration(minutes: 9),
          end: Duration(minutes: 9, seconds: 57),
          confidence: 1,
        ),
      ];
      final e = longEngine(minute * 25);
      await install(e);

      await e.transcribeFile(audio, localeId: 'en-US');

      expect(slices().take(2), [(minute * 0, minute * 10), (minute * 10, minute * 20)]);
    });

    test('a slice inside a long file keeps its own bounds and slice-relative timings', () async {
      runtime.segments = cut;
      final e = longEngine(minute * 60);
      await install(e);

      final transcript = await e.transcribeFile(
        audio,
        localeId: 'en-US',
        start: minute * 30,
        end: minute * 45,
      );

      expect(slices(), [(minute * 30, minute * 40), (minute * 39, minute * 45)]);
      expect(transcript.segments.map((s) => s.start), [Duration.zero, minute * 9]);
      expect(transcript.segments.last.end, minute * 15);
    });

    test(
      'a long slice drops each chunk\'s words far from the voice, on the slice\'s clock',
      () async {
        runtime.segments = cut;
        decoder = FakePcmDecoder(
          scratch: Directory('${root.path}/scratch'),
          fileDuration: minute * 60,
          framesPerSecond: 4,
        );
        final e = WhisperEngine(
          modelsDir: models,
          fetcher: fetcher,
          decoder: decoder,
          runtime: runtime,
          activity: FakeAudioActivity(ranges: [(start: minute * 39, end: minute * 40)]),
          clock: () => DateTime.utc(2026, 9, 6),
        );
        await install(e);

        final transcript = await e.transcribeFile(
          audio,
          localeId: 'en-US',
          start: minute * 30,
          end: minute * 45,
        );

        expect(transcript.segments.map((s) => s.start), [minute * 9]);
      },
    );

    test('a slice no longer than a chunk is decoded exactly as asked', () async {
      final e = longEngine(minute * 60);
      await install(e);

      await e.transcribeFile(audio, localeId: 'en-US', start: minute * 5, end: minute * 12);

      expect(slices(), [(minute * 5, minute * 12)]);
    });

    test(
      'a tail stamped past the chunk is kept and the next chunk starts at the boundary',
      () async {
        runtime.segments = const [
          WhisperSegment(
            text: 'real',
            start: Duration.zero,
            end: Duration(minutes: 9),
            confidence: 1,
          ),
          WhisperSegment(
            text: 'ghost',
            start: Duration(minutes: 10),
            end: Duration(minutes: 10, seconds: 3),
            confidence: 0.1,
          ),
        ];
        final e = longEngine(minute * 25);
        await install(e);

        final transcript = await e.transcribeFile(audio, localeId: 'en-US');

        expect(slices(), [
          (minute * 0, minute * 10),
          (minute * 10, minute * 20),
          (minute * 20, minute * 25),
        ]);
        expect(transcript.segments.map((s) => s.text), ['real', 'ghost', 'real', 'ghost', 'real']);
      },
    );

    test('a short slice past the end of the file decodes once and is empty', () async {
      final e = longEngine(minute * 2);
      await install(e);

      final transcript = await e.transcribeFile(
        audio,
        localeId: 'en-US',
        start: minute * 3,
        end: minute * 4,
      );

      expect(transcript.isEmpty, isTrue);
      expect(decoder.calls, hasLength(1));
      expect(runtime.runs, isEmpty);
    });

    test('a start past the end of the file is an empty transcript with no decode', () async {
      final e = longEngine(minute * 2);
      await install(e);

      final transcript = await e.transcribeFile(audio, localeId: 'en-US', start: minute * 5);

      expect(transcript.isEmpty, isTrue);
      expect(decoder.calls, isEmpty);
      expect(runtime.runs, isEmpty);
    });

    test('a cancel during a later chunk ends the run with no scratch file left', () async {
      runtime.segments = const [];
      final e = longEngine(minute * 25);
      await install(e);
      var gate = Completer<void>();
      decoder.gate = gate.future;

      final run = e.transcribeFile(audio, localeId: 'en-US');
      await until(() => decoder.calls.length == 1);
      final first = gate;
      gate = Completer<void>();
      decoder.gate = gate.future;
      first.complete();
      await until(() => decoder.calls.length == 2);
      await e.cancelBatches();
      gate.complete();

      await expectLater(run, throwsA(isA<TranscriptionFailed>()));
      expect(runtime.runs, hasLength(1));
      expect(decoder.calls, hasLength(2));
      expect(decoder.written.any((f) => f.existsSync()), isFalse);
    });

    test('progress climbs across chunks and ends at one', () async {
      runtime
        ..segments = cut
        ..progressSteps = const [0, 0.5, 1];
      final e = longEngine(minute * 25);
      await install(e);
      final seen = <double>[];

      await e.transcribeFileWithProgress(audio, localeId: 'en-US', onProgress: seen.add);

      expect(seen, hasLength(6));
      expect(seen, orderedEquals([...seen]..sort()));
      expect(seen.first, closeTo(0.2, 1e-9));
      expect(seen.last, closeTo(1, 1e-9));
    });

    test('a recording the decoder cannot find is missing before any chunk', () async {
      final e = longEngine(minute * 25);
      await install(e);
      decoder.throwOnDecode = PcmDecodeFailed.missing;

      await expectLater(
        e.transcribeFile(audio, localeId: 'en-US'),
        throwsA(isA<RecordingMissing>()),
      );
      expect(decoder.calls, isEmpty);
    });
  });

  group('model choice', () {
    test('the catalog is offered in order with the default selected', () {
      final e = engine();

      expect(e.models.map((m) => m.id), whisperCatalog.map((m) => m.id));
      expect(e.selectedModelId, whisperDefaultModelId);
    });

    test('an unknown model id is refused by selection, install, and removal', () {
      final e = engine();

      expect(() => e.selectModel('nope'), throwsArgumentError);
      expect(() => e.installModelById('nope'), throwsArgumentError);
      expect(() => e.removeModel('nope'), throwsArgumentError);
    });

    test(
      'an install reports zero when its turn begins, then the fetch fractions, then done',
      () async {
        fetcher = FakeModelFetcher(steps: const [0.2, 0.9]);
        final e = engine();

        final progress = await e.installModelById('tiny-q5_1').toList();

        expect(progress, const [
          ModelInstallProgress(fraction: 0, done: false),
          ModelInstallProgress(fraction: 0.2, done: false),
          ModelInstallProgress(fraction: 0.9, done: false),
          ModelInstallProgress(fraction: 1, done: true),
        ]);
        expect(await e.installedModels(), {'tiny-q5_1'});
        expect(fetcher.calls.single.source.toString(), startsWith(WhisperHosts.modelHost));
      },
    );

    test('an installed model answers done at once without fetching again', () async {
      final e = engine();
      await install(e, 'tiny-q5_1');

      final progress = await e.installModelById('tiny-q5_1').toList();

      expect(progress, const [ModelInstallProgress(fraction: 1, done: true)]);
      expect(fetcher.calls, hasLength(1));
    });

    test('a fetch failure surfaces with its reason and names its model', () async {
      fetcher = FakeModelFetcher(failWith: ModelInstallReason.offline);
      final e = engine();

      await expectLater(
        e.installModelById('tiny-q5_1').drain<void>(),
        throwsA(
          isA<ModelInstallFailed>()
              .having((f) => f.reason, 'reason', ModelInstallReason.offline)
              .having((f) => f.modelId, 'modelId', 'tiny-q5_1'),
        ),
      );
      expect(await e.installedModels(), isEmpty);
    });

    test('a fetch that lands a file of the wrong length is rejected, not installed', () async {
      fetcher = FakeModelFetcher(writtenBytes: 3);
      final e = engine();

      await expectLater(
        e.installModelById('tiny-q5_1').drain<void>(),
        throwsA(
          isA<ModelInstallFailed>().having((f) => f.reason, 'reason', ModelInstallReason.rejected),
        ),
      );
      expect(await e.installedModels(), isEmpty);
    });

    test('installs of different models run one after the other', () async {
      final gate = Completer<void>();
      fetcher = FakeModelFetcher(gate: gate.future);
      final e = engine();

      final first = e.installModelById('tiny-q5_1').drain<void>();
      final second = e.installModelById('base-q5_1').drain<void>();
      await until(() => fetcher.calls.isNotEmpty);
      await pumpEventQueue();
      expect(fetcher.calls, hasLength(1));

      fetcher.gate = null;
      gate.complete();
      await first;
      await second;
      expect(fetcher.calls, hasLength(2));
      expect(await e.installedModels(), {'tiny-q5_1', 'base-q5_1'});
    });

    test('a queued install cancelled before its turn never fetches', () async {
      final gate = Completer<void>();
      fetcher = FakeModelFetcher(gate: gate.future);
      final e = engine();

      final first = e.installModelById('tiny-q5_1').drain<void>();
      final queued = e.installModelById('base-q5_1').listen(null);
      await until(() => fetcher.calls.isNotEmpty);
      await queued.cancel();
      fetcher.gate = null;
      gate.complete();
      await first;
      await pumpEventQueue();

      expect(fetcher.calls.map((c) => c.into.path), [fileOf('tiny-q5_1').path]);
      expect(await e.installedModels(), {'tiny-q5_1'});
    });

    test('removing a model whose download is in flight is refused', () async {
      final gate = Completer<void>();
      fetcher = FakeModelFetcher(gate: gate.future);
      final e = engine();

      final install = e.installModelById('tiny-q5_1').drain<void>();
      await until(() => fetcher.calls.isNotEmpty);
      expect(await e.removeModel('tiny-q5_1'), isFalse);

      fetcher.gate = null;
      gate.complete();
      await install;
      expect(await e.removeModel('tiny-q5_1'), isTrue);
    });

    test('a release racing a model load leaves no dead session behind', () async {
      final loadGate = Completer<void>();
      runtime.loadGate = loadGate.future;
      final e = engine();
      await install(e);

      final first = e.transcribeFile(audio, localeId: 'en-US');
      await until(() => runtime.loads.isNotEmpty);
      final released = e.release();
      runtime.loadGate = null;
      loadGate.complete();
      await released;
      await expectLater(first, throwsA(isA<TranscriptionFailed>()));

      expect((await e.transcribeFile(audio, localeId: 'en-US')).fullText, 'hello');
      expect(runtime.loads, hasLength(2));
    });

    test(
      'removing the model a run is still loading is refused after the choice moved on',
      () async {
        final loadGate = Completer<void>();
        runtime.loadGate = loadGate.future;
        final e = engine();
        await install(e);
        await install(e, 'tiny-q5_1');

        final running = e.transcribeFile(audio, localeId: 'en-US');
        await until(() => runtime.loads.isNotEmpty);
        await e.selectModel('tiny-q5_1');
        expect(await e.removeModel(whisperDefaultModelId), isFalse);

        runtime.loadGate = null;
        loadGate.complete();
        await running;
        expect(await e.removeModel(whisperDefaultModelId), isTrue);
      },
    );

    test('a removal stays refused while a second install of the same model still runs', () async {
      final gate = Completer<void>();
      fetcher = FakeModelFetcher(gate: gate.future);
      final e = engine();

      final first = e.installModelById('tiny-q5_1').listen(null);
      final second = e.installModelById('tiny-q5_1').drain<void>();
      await until(() => fetcher.calls.isNotEmpty);
      await first.cancel();
      expect(await e.removeModel('tiny-q5_1'), isFalse);

      fetcher.gate = null;
      gate.complete();
      await second;
      expect(await e.installedModels(), {'tiny-q5_1'});
    });

    test('a consumer leaving an install hands the turn to the next', () async {
      final gate = Completer<void>();
      fetcher = FakeModelFetcher(gate: gate.future);
      final e = engine();

      final sub = e.installModelById('tiny-q5_1').listen(null);
      await until(() => fetcher.calls.isNotEmpty);
      await sub.cancel();
      fetcher.gate = null;
      gate.complete();

      await e.installModelById('base-q5_1').drain<void>();
      expect(fetcher.cancelled, 1);
      expect(await e.installedModels(), {'base-q5_1'});
    });

    test('removing a model deletes its file and any part and closes its session', () async {
      final e = engine();
      await install(e);
      await e.transcribeFile(audio, localeId: 'en-US');
      final file = fileOf(whisperDefaultModelId);
      final part = File('${file.path}.part');
      await part.writeAsBytes([1]);

      expect(await e.removeModel(whisperDefaultModelId), isTrue);

      expect(file.existsSync(), isFalse);
      expect(part.existsSync(), isFalse);
      expect(runtime.closes, 1);
    });

    test('removing a model that is not there answers false', () async {
      final e = engine();

      expect(await e.removeModel('tiny-q5_1'), isFalse);
    });

    test(
      'removing the selected model keeps the selection so its download is offered again',
      () async {
        final e = engine();
        await install(e);

        await e.removeModel(whisperDefaultModelId);

        expect(e.selectedModelId, whisperDefaultModelId);
        expect(await e.isModelInstalled(localeId: 'en-US'), isFalse);
      },
    );

    test('removing the model a first-use install is fetching is refused', () async {
      final gate = Completer<void>();
      fetcher = FakeModelFetcher(gate: gate.future);
      final e = engine();

      final run = e.transcribeFile(audio, localeId: 'en-US');
      await until(() => fetcher.calls.isNotEmpty);
      expect(await e.removeModel(whisperDefaultModelId), isFalse);

      fetcher.gate = null;
      gate.complete();
      await run;
      expect(await e.installedModels(), {whisperDefaultModelId});
    });

    test('removing the model a run holds open is refused even after the choice moved on', () async {
      final gate = Completer<void>();
      runtime.gate = gate.future;
      final e = engine();
      await install(e);
      await install(e, 'tiny-q5_1');

      final running = e.transcribeFile(audio, localeId: 'en-US');
      await until(() => runtime.runs.isNotEmpty);
      await e.selectModel('tiny-q5_1');
      expect(await e.removeModel(whisperDefaultModelId), isFalse);

      runtime.gate = null;
      gate.complete();
      await running;
      expect(runtime.aborts, 0);
    });

    test('a queued run keeps the model chosen when it was queued', () async {
      final gate = Completer<void>();
      runtime.gate = gate.future;
      final e = engine();
      await install(e);
      await install(e, 'tiny-q5_1');

      final first = e.transcribeFile(audio, localeId: 'en-US');
      final queued = e.transcribeFile(audio, localeId: 'en-US');
      await until(() => runtime.runs.isNotEmpty);
      await e.selectModel('tiny-q5_1');
      runtime.gate = null;
      gate.complete();
      await first;
      await queued;

      expect(runtime.runs.map((r) => r.modelPath), [
        fileOf(whisperDefaultModelId).path,
        fileOf(whisperDefaultModelId).path,
      ]);
    });

    test('removing the model a queued run holds is refused until the run ends', () async {
      final gate = Completer<void>();
      runtime.gate = gate.future;
      final e = engine();
      await install(e);
      await install(e, 'tiny-q5_1');
      await e.selectModel('tiny-q5_1');

      final first = e.transcribeFile(audio, localeId: 'en-US');
      await until(() => runtime.runs.isNotEmpty);
      await e.selectModel(whisperDefaultModelId);
      final queued = e.transcribeFile(audio, localeId: 'en-US');
      await e.selectModel('tiny-q5_1');
      expect(await e.removeModel(whisperDefaultModelId), isFalse);

      runtime.gate = null;
      gate.complete();
      await first;
      await queued;
      expect(await e.removeModel(whisperDefaultModelId), isTrue);
    });

    test('a release racing a load that fails reads as a cancel, and the next run loads', () async {
      final loadGate = Completer<void>();
      runtime
        ..loadGate = loadGate.future
        ..failLoad = true;
      final e = engine();
      await install(e);

      final first = e.transcribeFile(audio, localeId: 'en-US');
      await until(() => runtime.loads.isNotEmpty);
      final released = e.release();
      loadGate.complete();
      await released;

      await expectLater(
        first,
        throwsA(isA<TranscriptionFailed>().having((f) => f.message, 'message', 'cancelled')),
      );
      runtime
        ..loadGate = null
        ..failLoad = false;
      expect((await e.transcribeFile(audio, localeId: 'en-US')).fullText, 'hello');
    });

    test('a run queued while its model is being removed waits, then fetches it afresh', () async {
      final e = engine();
      await install(e);

      final removing = e.removeModel(whisperDefaultModelId);
      final run = e.transcribeFile(audio, localeId: 'en-US');

      expect(await removing, isTrue);
      expect((await run).fullText, 'hello');
      expect(fetcher.calls, hasLength(2));
      expect(fileOf(whisperDefaultModelId).existsSync(), isTrue);
    });

    test(
      'an install started during its model\'s removal waits it out and fetches afresh',
      () async {
        final e = engine();
        await install(e);

        final removing = e.removeModel(whisperDefaultModelId);
        final installing = install(e);

        expect(await removing, isTrue);
        await installing;
        expect(fetcher.calls, hasLength(2));
        expect(fileOf(whisperDefaultModelId).existsSync(), isTrue);
      },
    );

    test('a second removal during the first answers false once the first is done', () async {
      final e = engine();
      await install(e);

      final first = e.removeModel(whisperDefaultModelId);
      final second = e.removeModel(whisperDefaultModelId);

      expect(await first, isTrue);
      expect(await second, isFalse);
    });

    test('a run cancelled while it waits out its model\'s removal fetches nothing', () async {
      final e = engine();
      await install(e);
      await e.transcribeFile(audio, localeId: 'en-US');
      final closing = Completer<void>();
      runtime.closeGate = closing.future;

      final removing = e.removeModel(whisperDefaultModelId);
      final run = e.transcribeFile(audio, localeId: 'en-US');
      await pumpEventQueue();
      await e.cancelBatches();
      closing.complete();

      expect(await removing, isTrue);
      await expectLater(run, throwsA(isA<TranscriptionFailed>()));
      expect(fetcher.calls, hasLength(1));
      expect(fileOf(whisperDefaultModelId).existsSync(), isFalse);
    });

    test('an install cancelled while the file is being checked stays quiet', () async {
      final e = engine();
      await install(e, 'tiny-q5_1');
      final errors = <Object>[];

      await runZonedGuarded(() async {
        final sub = e.installModelById('tiny-q5_1').listen(null);
        await Future<void>.delayed(Duration.zero);
        await sub.cancel();
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }, (error, _) => errors.add(error));

      expect(errors, isEmpty);
    });

    test('releasing the engine under a run cancels it and the queued run still lands', () async {
      final runGate = Completer<void>();
      final closeGate = Completer<void>();
      runtime.gate = runGate.future;
      runtime.closeGate = closeGate.future;
      final e = engine();
      await install(e);

      final first = e.transcribeFile(audio, localeId: 'en-US');
      final queued = e.transcribeFile(audio, localeId: 'en-US');
      await until(() => runtime.runs.isNotEmpty);
      runtime.gate = null;
      final released = e.release();
      runGate.complete();
      await expectLater(
        first,
        throwsA(isA<TranscriptionFailed>().having((f) => f.message, 'message', 'cancelled')),
      );
      closeGate.complete();
      await released;

      expect((await queued).fullText, 'hello');
      expect(runtime.loads, hasLength(2));
      expect(runtime.disposes, 1);
    });

    test('removing the selected model is refused while a run is in flight', () async {
      final gate = Completer<void>();
      runtime.gate = gate.future;
      final e = engine();
      await install(e);

      final running = e.transcribeFile(audio, localeId: 'en-US');
      await until(() => runtime.runs.isNotEmpty);
      expect(await e.removeModel(whisperDefaultModelId), isFalse);

      runtime.gate = null;
      gate.complete();
      await running;
      expect(await e.removeModel(whisperDefaultModelId), isTrue);
    });

    test('a selected model whose file vanished reads as not installed', () async {
      final e = engine();
      await install(e);
      await fileOf(whisperDefaultModelId).delete();

      expect(await e.isModelInstalled(localeId: 'en-US'), isFalse);
      expect(await e.installedModels(), isEmpty);
    });

    test('releasing the engine closes it, disposes the runtime, and the next run loads', () async {
      final e = engine();
      await install(e);
      await e.transcribeFile(audio, localeId: 'en-US');

      await e.release();
      await e.transcribeFile(audio, localeId: 'en-US');

      expect(runtime.closes, 1);
      expect(runtime.disposes, 1);
      expect(runtime.loads, hasLength(2));
    });
  });

  group('acceleration', () {
    final tiny = whisperModelById('tiny-q5_1')!;
    List<int> encoderZip({bool withDirectory = true}) => zipOf({
      if (withDirectory) '${tiny.encoderDirName}/': null,
      '${withDirectory ? '${tiny.encoderDirName}/' : ''}weights/weight.bin': List.filled(4096, 7),
      '${withDirectory ? '${tiny.encoderDirName}/' : ''}coremldata.bin': [1, 2, 3],
    });

    WhisperEngine accelerated({bool on = true, bool can = true}) => WhisperEngine(
      modelsDir: models,
      fetcher: fetcher,
      decoder: decoder,
      runtime: runtime,
      initialModelId: tiny.id,
      canAccelerate: can,
      initiallyAccelerated: on,
      clock: () => DateTime.utc(2026, 9, 6),
    );

    Directory encoderDir() => Directory('${models.path}/${tiny.encoderDirName}');

    setUp(() {
      fetcher = FakeModelFetcher(bodies: {tiny.encoder.fileName: encoderZip()});
    });

    test(
      'with acceleration on an install fetches the encoder after the model and unpacks it beside it',
      () async {
        final e = accelerated();
        final events = await e.installModelById(tiny.id).toList();

        expect(fetcher.calls.map((c) => c.source.pathSegments.last), [
          tiny.fileName,
          tiny.encoder.fileName,
        ]);
        expect(encoderDir().existsSync(), isTrue);
        expect(File('${encoderDir().path}/coremldata.bin').readAsBytesSync(), [1, 2, 3]);
        expect(File('${models.path}/${tiny.encoder.fileName}').existsSync(), isFalse);
        expect(Directory('${models.path}/.unpack-${tiny.encoderDirName}').existsSync(), isFalse);
        final fractions = events.map((p) => p.fraction).toList();
        expect(fractions, orderedEquals([...fractions]..sort()));
        expect(events.where((p) => p.preparing), isNotEmpty);
        expect(events.last.done, isTrue);
        expect(await e.acceleratedModels(), {tiny.id});
        expect(runtime.loads, [fileOf(tiny.id).path]);
      },
    );

    test('acceleration for a model that is not there fetches nothing', () async {
      final e = accelerated();

      await e.installAcceleration(tiny.id).drain<void>();

      expect(fetcher.calls, isEmpty);
      expect(encoderDir().existsSync(), isFalse);
    });

    test('installing acceleration on an installed model fetches only the encoder', () async {
      final e = accelerated(on: false);
      await install(e);
      await e.setAccelerated(true);
      fetcher.calls.clear();

      await e.installAcceleration(tiny.id).drain<void>();

      expect(fetcher.calls.map((c) => c.source.pathSegments.last), [tiny.encoder.fileName]);
      expect(encoderDir().existsSync(), isTrue);
    });

    test('with acceleration off an install fetches the model alone', () async {
      final e = accelerated(on: false);

      await install(e);

      expect(fetcher.calls.map((c) => c.source.pathSegments.last), [tiny.fileName]);
      expect(await e.acceleratedModels(), isEmpty);
    });

    test('turning acceleration off deletes every encoder', () async {
      final e = accelerated();
      await install(e);
      expect(encoderDir().existsSync(), isTrue);

      await e.setAccelerated(false);

      expect(e.accelerated, isFalse);
      expect(encoderDir().existsSync(), isFalse);
      expect(await e.acceleratedModels(), isEmpty);
    });

    test('turning acceleration off under a run keeps its encoder until the run ends', () async {
      final e = accelerated();
      await install(e);
      final gate = Completer<void>();
      runtime.gate = gate.future;
      final run = e.transcribeFile(audio, localeId: 'en-US');
      await until(() => runtime.runs.length == 1);

      await e.setAccelerated(false);
      expect(encoderDir().existsSync(), isTrue);

      gate.complete();
      await run;
      expect(encoderDir().existsSync(), isFalse);
      expect(runtime.closes, 1);
    });

    test('a leftover encoder is deleted before a load with acceleration off', () async {
      final e = accelerated(on: false);
      await install(e);
      await encoderDir().create(recursive: true);

      await e.transcribeFile(audio, localeId: 'en-US');

      expect(encoderDir().existsSync(), isFalse);
      expect(runtime.loads, hasLength(1));
    });

    test('removing a model deletes its encoder too', () async {
      final e = accelerated();
      await install(e);

      expect(await e.removeModel(tiny.id), isTrue);

      expect(encoderDir().existsSync(), isFalse);
      expect(fileOf(tiny.id).existsSync(), isFalse);
    });

    test('an archive without the encoder directory is rejected and leaves nothing', () async {
      fetcher = FakeModelFetcher(bodies: {tiny.encoder.fileName: encoderZip(withDirectory: false)});
      final e = accelerated();

      await expectLater(
        e.installModelById(tiny.id).drain<void>(),
        throwsA(
          isA<ModelInstallFailed>().having((f) => f.reason, 'reason', ModelInstallReason.rejected),
        ),
      );

      expect(encoderDir().existsSync(), isFalse);
      expect(Directory('${models.path}/.unpack-${tiny.encoderDirName}').existsSync(), isFalse);
      expect(await e.installedModels(), {tiny.id});
    });

    test(
      'a first-use install with the switch on lands its encoder and the run still goes',
      () async {
        final e = accelerated();

        final transcript = await e.transcribeFile(audio, localeId: 'en-US');

        expect(transcript.fullText, 'hello');
        expect(encoderDir().existsSync(), isTrue);
        expect(fetcher.calls.map((c) => c.source.pathSegments.last), [
          tiny.fileName,
          tiny.encoder.fileName,
        ]);
        expect(runtime.loads, hasLength(1));
      },
    );

    test('a switch flipped off during the encoder download leaves nothing behind', () async {
      final e = accelerated(on: false);
      await install(e);
      await e.setAccelerated(true);
      final gate = Completer<void>();
      fetcher.gate = gate.future;
      final done = e.installAcceleration(tiny.id).drain<void>();
      await until(() => fetcher.calls.isNotEmpty);

      await e.setAccelerated(false);
      gate.complete();
      await done;

      expect(encoderDir().existsSync(), isFalse);
      expect(await e.acceleratedModels(), isEmpty);
    });

    test(
      'an encoder download cancelled after the switch went off leaves no partial file',
      () async {
        final e = accelerated(on: false);
        await install(e);
        await e.setAccelerated(true);
        final gate = Completer<void>();
        fetcher.gate = gate.future;
        final sub = e.installAcceleration(tiny.id).listen(null);
        await until(() => fetcher.calls.isNotEmpty);
        final partial = File('${models.path}/${tiny.encoder.fileName}$modelPartSuffix')
          ..writeAsBytesSync([1, 2, 3]);

        await e.setAccelerated(false);
        await sub.cancel();

        expect(partial.existsSync(), isFalse);
        expect(await e.acceleratedModels(), isEmpty);
      },
    );

    test('a switch flipped on during the model download still fetches its encoder', () async {
      final e = accelerated(on: false);
      final gate = Completer<void>();
      fetcher.gate = gate.future;
      final done = e.installModelById(tiny.id).drain<void>();
      await until(() => fetcher.calls.isNotEmpty);

      await e.setAccelerated(true);
      gate.complete();
      await done;

      expect(fetcher.calls.map((c) => c.source.pathSegments.last), [
        tiny.fileName,
        tiny.encoder.fileName,
      ]);
      expect(encoderDir().existsSync(), isTrue);
    });

    test('a warm-up load that fails keeps the files and fails the install as unopenable', () async {
      runtime.failLoad = true;
      final e = accelerated();

      await expectLater(
        e.installModelById(tiny.id).drain<void>(),
        throwsA(
          isA<ModelInstallFailed>().having(
            (f) => f.reason,
            'reason',
            ModelInstallReason.loadFailed,
          ),
        ),
      );
      expect(fileOf(tiny.id).existsSync(), isTrue);
      expect(encoderDir().existsSync(), isTrue);
      expect(await e.acceleratedModels(), {tiny.id});
    });

    test('a release during the warm-up load leaves no dead session for the next run', () async {
      final loadGate = Completer<void>();
      runtime.loadGate = loadGate.future;
      final e = accelerated();
      final installing = install(e, tiny.id);
      await until(() => runtime.loads.isNotEmpty);

      final released = e.release();
      runtime.loadGate = null;
      loadGate.complete();
      await released;
      await installing;

      expect((await e.transcribeFile(audio, localeId: 'en-US')).fullText, 'hello');
    });

    test('a warm-up of a model other than the choice closes it again', () async {
      final e = accelerated();
      await e.selectModel('base-q5_1');

      await e.installModelById(tiny.id).drain<void>();

      expect(runtime.loads, hasLength(1));
      expect(runtime.closes, 1);
    });

    test(
      'an engine that cannot accelerate keeps the toggle off and fetches nothing extra',
      () async {
        final e = accelerated(can: false);

        await e.setAccelerated(true);
        await e.installAcceleration(tiny.id).drain<void>();
        await install(e);

        expect(e.accelerated, isFalse);
        expect(fetcher.calls.map((c) => c.source.pathSegments.last), [tiny.fileName]);
      },
    );
  });

  group('the per-language view of one model', () {
    test(
      'every language reads installed once the selected model is, and supported before',
      () async {
        final e = engine();

        expect(await e.isModelInstalled(localeId: 'ka-GE'), isFalse);
        expect(await e.installedLocales(), isEmpty);
        expect((await e.localeStatus(localeId: 'de-AT')).status, ModelAssetStatus.supported);

        await install(e);

        expect(await e.isModelInstalled(localeId: 'ka-GE'), isTrue);
        expect(await e.installedLocales(), hasLength(99));
        final status = await e.localeStatus(localeId: 'de-AT');
        expect(status.status, ModelAssetStatus.installed);
        expect(status.reserved, isTrue);
        expect(status.resolvedTag, 'de-DE');
      },
    );

    test('an unknown language is unsupported and unreserved', () async {
      final e = engine();

      final status = await e.localeStatus(localeId: 'xx-XX');

      expect(status.status, ModelAssetStatus.unsupported);
      expect(status.reserved, isFalse);
      expect(status.resolvedTag, 'xx-XX');
    });

    test('installing a language installs the selected model', () async {
      final e = engine();

      await e.installModel(localeId: 'tr-TR').drain<void>();

      expect(await e.installedModels(), {whisperDefaultModelId});
    });

    test('languages cannot be removed and there is no reservation cap', () async {
      final e = engine();
      await install(e);

      expect(await e.removeLanguage(localeId: 'en-US'), isFalse);
      expect((await e.reservationInfo()).max, 0);
      expect(await e.installedModels(), {whisperDefaultModelId});
    });
  });

  group('voice activity', () {
    const words = WhisperSegment(
      text: ' the words',
      start: Duration(milliseconds: 500),
      end: Duration(seconds: 2),
      confidence: 0.9,
    );
    const thanks = WhisperSegment(
      text: ' Thank you.',
      start: Duration(seconds: 6),
      end: Duration(seconds: 8),
      confidence: 0.7,
    );

    WhisperEngine engineWith(FakeAudioActivity activity) => WhisperEngine(
      modelsDir: models,
      fetcher: fetcher,
      decoder: FakePcmDecoder(
        scratch: Directory('${root.path}/scratch'),
        fileDuration: const Duration(seconds: 10),
      ),
      runtime: runtime,
      activity: activity,
      clock: () => DateTime.utc(2026, 9, 6),
    );

    test('a slice with no voice runs nothing, loads no model and lands no words', () async {
      runtime.segments = const [thanks];
      final e = engineWith(FakeAudioActivity());
      await install(e);

      final transcript = await e.transcribeFile(audio, localeId: 'fr-FR');

      expect(transcript.fullText, isEmpty);
      expect(runtime.runs, isEmpty);
      expect(runtime.loads, isEmpty);
    });

    test('a single short word is still heard', () async {
      runtime.segments = const [
        WhisperSegment(
          text: ' No.',
          start: Duration(seconds: 1),
          end: Duration(milliseconds: 1200),
          confidence: 0.8,
        ),
      ];
      final e = engineWith(
        FakeAudioActivity(
          ranges: const [(start: Duration(seconds: 1), end: Duration(milliseconds: 1200))],
        ),
      );
      await install(e);

      final transcript = await e.transcribeFile(audio, localeId: 'en-US');

      expect(transcript.fullText, 'No.');
    });

    test('what whisper writes into the silence around a voice is dropped', () async {
      runtime.segments = const [words, thanks];
      final e = engineWith(
        FakeAudioActivity(
          ranges: const [(start: Duration(milliseconds: 400), end: Duration(seconds: 2))],
        ),
      );
      await install(e);

      final transcript = await e.transcribeFile(audio, localeId: 'en-US');

      expect(transcript.fullText, 'the words');
    });

    test('a slice is asked about its own bounds, and its voice read on its own clock', () async {
      runtime.segments = const [words, thanks];
      final activity = FakeAudioActivity(
        ranges: const [(start: Duration(seconds: 7), end: Duration(seconds: 9))],
      );
      final e = engineWith(activity);
      await install(e);

      final transcript = await e.transcribeFile(
        audio,
        localeId: 'en-US',
        start: const Duration(seconds: 1),
        end: const Duration(seconds: 12),
      );

      expect(activity.calls.single.start, const Duration(seconds: 1));
      expect(activity.calls.single.end, const Duration(seconds: 10));
      expect(transcript.fullText, 'Thank you.');
    });

    test('a probe that cannot tell keeps every word', () async {
      runtime.segments = const [words, thanks];
      final e = engineWith(FakeAudioActivity(ranges: null));
      await install(e);

      final transcript = await e.transcribeFile(audio, localeId: 'en-US');

      expect(transcript.fullText, 'the words Thank you.');
    });
  });
}
