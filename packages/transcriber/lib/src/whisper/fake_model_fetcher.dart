import 'dart:async';
import 'dart:io';

import 'package:transcriber/src/transcribe/transcription_exception.dart';
import 'package:transcriber/src/whisper/model_fetcher.dart';

/// One fetch as the fake saw it.
final class FetchCall {
  const FetchCall({required this.source, required this.into, required this.expectedBytes});

  final Uri source;
  final File into;
  final int expectedBytes;
}

/// Deterministic [ModelFetcher] for tests. Emits [steps], waits on [gate], then
/// either fails with [failWith] or puts a sparse file of the expected length in
/// place ([writtenBytes] overrides that length, for a caller's whole-file
/// check to fail), so no real bytes are written unless [bodies] names the
/// source's file, whose bytes then land whole. [cancelled] counts
/// unsubscribes before completion, and nothing lands after one, like the real
/// fetcher.
class FakeModelFetcher implements ModelFetcher {
  FakeModelFetcher({
    this.steps = const [0.5],
    this.failWith,
    this.gate,
    this.writtenBytes,
    this.bodies = const {},
  });

  final List<double> steps;
  final ModelInstallReason? failWith;
  Future<void>? gate;
  final int? writtenBytes;

  /// Real bytes for a source, by its file name.
  final Map<String, List<int>> bodies;

  final List<FetchCall> calls = [];
  int cancelled = 0;

  @override
  Stream<double> fetch(
    Uri source, {
    required File into,
    required int expectedBytes,
    required String expectedSha256,
  }) {
    if (expectedBytes <= 0) throw ArgumentError.value(expectedBytes, 'expectedBytes');
    calls.add(FetchCall(source: source, into: into, expectedBytes: expectedBytes));
    var done = false;
    var unsubscribed = false;
    late final StreamController<double> controller;
    controller = StreamController<double>(
      onListen: () async {
        for (final step in steps) {
          if (unsubscribed) return;
          controller.add(step);
        }
        final held = gate;
        if (held != null) await held;
        if (unsubscribed) return;
        final reason = failWith;
        if (reason != null) {
          controller.addError(ModelInstallFailed('fake fetch failed', null, reason));
        } else {
          await into.parent.create(recursive: true);
          final body = bodies[source.pathSegments.last];
          if (body != null) {
            await into.writeAsBytes(body);
          } else {
            final raf = await into.open(mode: FileMode.write);
            await raf.truncate(writtenBytes ?? expectedBytes);
            await raf.close();
          }
          controller.add(1);
        }
        done = true;
        await controller.close();
      },
      onCancel: () {
        unsubscribed = true;
        if (!done) cancelled++;
      },
    );
    return controller.stream;
  }
}
