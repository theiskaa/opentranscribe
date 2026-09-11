import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/src/transcribe/install_wait.dart';
import 'package:transcriber/src/transcribe/transcription_engine.dart';

void main() {
  const cancelled = 'cancelled';

  test('the wait lands when the install does and hears its progress', () async {
    final seen = <double>[];
    final wait = InstallWait(
      Stream.fromIterable(const [
        ModelInstallProgress(fraction: 0.5, done: false),
        ModelInstallProgress(fraction: 1, done: true),
      ]),
      cancelled: cancelled,
      onProgress: (p) => seen.add(p.fraction),
    );

    await wait.done;

    expect(seen, [0.5, 1]);
  });

  test('the wait fails with the install error', () async {
    final wait = InstallWait(Stream.error(StateError('broke')), cancelled: cancelled);

    await expectLater(wait.done, throwsStateError);
  });

  test('a cancel ends the download and fails the wait, which would otherwise park', () async {
    var listening = true;
    final install = StreamController<ModelInstallProgress>(onCancel: () => listening = false);
    final wait = InstallWait(install.stream, cancelled: cancelled);

    await wait.cancel();

    expect(listening, isFalse);
    await expectLater(wait.done, throwsA(cancelled));
    await install.close();
  });

  test('a cancel whose teardown throws still fails the wait', () async {
    final install = StreamController<ModelInstallProgress>(
      onCancel: () => Future<void>.error(StateError('teardown')),
    );
    final wait = InstallWait(install.stream, cancelled: cancelled);

    await expectLater(wait.cancel(), throwsStateError);
    await expectLater(wait.done, throwsA(cancelled));
    await install.close();
  });
}
