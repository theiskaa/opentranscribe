import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/src/audio/fake_audio_composer.dart';
import 'package:transcriber/src/transcribe/transcription_exception.dart';

void main() {
  test('starts are the cumulative durations of the inputs before each', () async {
    final composer = FakeAudioComposer(
      durations: {'a.m4a': const Duration(seconds: 3), 'b.m4a': const Duration(seconds: 1)},
    );

    final composition = await composer.concatenate(['a.m4a', 'b.m4a', 'c.m4a']);

    expect(composition.starts, const [Duration.zero, Duration(seconds: 3), Duration(seconds: 4)]);
    expect(composition.duration, const Duration(seconds: 6));
    expect(composer.calls, [
      ['a.m4a', 'b.m4a', 'c.m4a'],
    ]);
  });

  test('every merge lands under a fresh name whatever the extension', () async {
    final composer = FakeAudioComposer(name: 'merged');

    final first = await composer.concatenate(['a', 'b']);
    final second = await composer.concatenate(['a', 'b']);

    expect(first.name, 'merged');
    expect(second.name, isNot(first.name));
  });

  test('explicit starts and duration win over the derived values', () async {
    final composer = FakeAudioComposer(
      starts: const [Duration.zero, Duration(seconds: 9)],
      duration: const Duration(seconds: 11),
    );

    final composition = await composer.concatenate(['a', 'b']);

    expect(composition.starts, const [Duration.zero, Duration(seconds: 9)]);
    expect(composition.duration, const Duration(seconds: 11));
  });

  test('a gated merge does not complete until the gate does', () async {
    final gate = Completer<void>();
    final composer = FakeAudioComposer(gate: gate.future);
    var done = false;

    final merge = composer.concatenate(['a', 'b']).then((_) => done = true);
    await Future<void>.delayed(Duration.zero);
    expect(done, isFalse);
    gate.complete();
    await merge;

    expect(done, isTrue);
  });

  test('a path or an empty name is refused synchronously, like the real one', () {
    final composer = FakeAudioComposer();

    expect(() => composer.concatenate(['a', 'sub/b']), throwsArgumentError);
    expect(() => composer.concatenate(['a', '']), throwsArgumentError);
    expect(composer.calls, isEmpty);
  });

  test('a failing composer still records the call', () async {
    final composer = FakeAudioComposer(throwOnConcatenate: true);

    await expectLater(composer.concatenate(['a', 'b']), throwsA(isA<AudioComposeFailed>()));

    expect(composer.calls, hasLength(1));
  });
}
