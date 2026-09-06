import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/src/transcribe/transcription_exception.dart';
import 'package:transcriber/src/whisper/fake_pcm_decoder.dart';
import 'package:transcriber/src/whisper/pcm_decoder.dart';

void main() {
  late Directory scratch;

  setUp(() async => scratch = await Directory.systemTemp.createTemp('otr-pcm-'));
  tearDown(() async => scratch.delete(recursive: true));

  test('a decode records its bounds and writes a file sized to the slice', () async {
    final decoder = FakePcmDecoder(scratch: scratch);

    final decoded = await decoder.decode(
      File('/recordings/otr-a.m4a'),
      start: const Duration(seconds: 1),
      end: const Duration(milliseconds: 2500),
    );

    expect(decoder.calls.single.path, '/recordings/otr-a.m4a');
    expect(decoder.calls.single.start, const Duration(seconds: 1));
    expect(decoder.calls.single.end, const Duration(milliseconds: 2500));
    expect(decoded.frames, DecodedPcm.sampleRate * 3 ~/ 2);
    expect(decoded.file.lengthSync(), decoded.frames * 4);
    expect(decoded.file.path, startsWith(scratch.path));
  });

  test('a slice with no end covers the default duration from its start', () async {
    final decoder = FakePcmDecoder(scratch: scratch, defaultDuration: const Duration(seconds: 3));

    final decoded = await decoder.decode(File('/a.m4a'), start: const Duration(seconds: 5));

    expect(decoded.duration, const Duration(seconds: 3));
  });

  test('a slice holding no frames fails as decode_empty like the real one', () async {
    final decoder = FakePcmDecoder(scratch: scratch);

    await expectLater(
      decoder.decode(
        File('/a.m4a'),
        start: const Duration(seconds: 2),
        end: const Duration(seconds: 2),
      ),
      throwsA(isA<PcmDecodeFailed>().having((e) => e.code, 'code', 'decode_empty')),
    );
    expect(decoder.written, isEmpty);
  });

  test('a scripted failure throws with its code and writes nothing', () async {
    final decoder = FakePcmDecoder(scratch: scratch, throwOnDecode: 'decode_unreadable');

    await expectLater(
      decoder.decode(File('/a.m4a')),
      throwsA(isA<PcmDecodeFailed>().having((e) => e.code, 'code', 'decode_unreadable')),
    );
    expect(decoder.written, isEmpty);
  });

  test('an empty path or a negative bound is refused synchronously, like the real one', () {
    final decoder = FakePcmDecoder(scratch: scratch);

    expect(() => decoder.decode(File('')), throwsArgumentError);
    expect(
      () => decoder.decode(File('/a.m4a'), start: const Duration(seconds: -1)),
      throwsArgumentError,
    );
    expect(decoder.calls, isEmpty);
  });

  test('a gate holds the decode open until it completes', () async {
    final gate = Completer<void>();
    final decoder = FakePcmDecoder(scratch: scratch, gate: gate.future);
    var done = false;

    final pending = decoder.decode(File('/a.m4a')).then((_) => done = true);
    await Future<void>.delayed(Duration.zero);
    expect(done, isFalse);
    expect(decoder.calls, hasLength(1));

    gate.complete();
    await pending;
    expect(done, isTrue);
  });
}
