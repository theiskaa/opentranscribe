import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/src/transcribe/transcription_exception.dart';
import 'package:transcriber/src/whisper/fake_model_fetcher.dart';

void main() {
  late Directory dir;

  setUp(() async => dir = await Directory.systemTemp.createTemp('otr-fake-fetch-'));
  tearDown(() async => dir.delete(recursive: true));

  test(
    'a fetch replays its steps, ends at one, and leaves a file of the expected length',
    () async {
      final fetcher = FakeModelFetcher(steps: const [0.25, 0.75]);
      final into = File('${dir.path}/m/model.bin');

      final fractions = await fetcher
          .fetch(Uri.parse('https://h/x.bin'), into: into, expectedBytes: 4096, expectedSha256: 'a')
          .toList();

      expect(fractions, [0.25, 0.75, 1]);
      expect(into.lengthSync(), 4096);
      expect(fetcher.calls.single.expectedBytes, 4096);
    },
  );

  test('a scripted failure carries its reason and writes nothing', () async {
    final fetcher = FakeModelFetcher(failWith: ModelInstallReason.offline);
    final into = File('${dir.path}/model.bin');

    await expectLater(
      fetcher
          .fetch(Uri.parse('https://h/x.bin'), into: into, expectedBytes: 10, expectedSha256: 'a')
          .drain<void>(),
      throwsA(
        isA<ModelInstallFailed>().having((e) => e.reason, 'reason', ModelInstallReason.offline),
      ),
    );
    expect(into.existsSync(), isFalse);
  });

  test('a cancel before completion is counted and completes nothing', () async {
    final gate = Completer<void>();
    final fetcher = FakeModelFetcher(gate: gate.future);
    final into = File('${dir.path}/model.bin');

    final sub = fetcher
        .fetch(Uri.parse('https://h/x.bin'), into: into, expectedBytes: 10, expectedSha256: 'a')
        .listen(null);
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    gate.complete();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(fetcher.cancelled, 1);
    expect(into.existsSync(), isFalse);
  });

  test('a non-positive expected size is refused synchronously, like the real one', () {
    final fetcher = FakeModelFetcher();

    expect(
      () => fetcher.fetch(
        Uri.parse('https://h/x.bin'),
        into: File('${dir.path}/model.bin'),
        expectedBytes: 0,
        expectedSha256: 'a',
      ),
      throwsArgumentError,
    );
    expect(fetcher.calls, isEmpty);
  });
}
