import 'dart:async';

import 'package:transcriber/src/transcribe/transcription_engine.dart';

/// An install stream awaited as one future. [done] completes when the stream
/// does and fails with its error; [cancel] ends the download and fails [done]
/// with the given cancelled error, since a cancelled subscription fires
/// neither done nor error and a waiter would otherwise park forever.
final class InstallWait {
  InstallWait(
    Stream<ModelInstallProgress> install, {
    required this._cancelled,
    void Function(ModelInstallProgress progress)? onProgress,
  }) {
    _sub = install.listen(
      onProgress,
      onError: (Object error, StackTrace stack) {
        if (!_done.isCompleted) _done.completeError(error, stack);
      },
      onDone: () {
        if (!_done.isCompleted) _done.complete();
      },
    );
  }

  final Object _cancelled;
  final Completer<void> _done = Completer<void>();
  late final StreamSubscription<ModelInstallProgress> _sub;

  Future<void> get done => _done.future;

  Future<void> cancel() async {
    try {
      await _sub.cancel();
    } finally {
      if (!_done.isCompleted) _done.completeError(_cancelled);
    }
  }
}
