import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import 'package:transcriber/src/whisper/whisper_runtime.dart';
import 'package:transcriber/src/whisper/whisper_shim.dart';

// ignore_for_file: prefer_initializing_formals
// Public parameters assigned to private fields; the lint wants the fields public.

/// The [WhisperRuntime] over the shim, on one worker isolate that owns the
/// whisper context: a run blocks that isolate and nothing else. The abort
/// flag lives in native memory owned by this isolate, so a cancel reaches the
/// worker mid-run without a message. [threads] is what every run gets;
/// [useGpu] is handed to whisper's context init as is.
class FfiWhisperRuntime implements WhisperRuntime {
  FfiWhisperRuntime({required int threads, bool useGpu = true})
    : assert(threads >= 1, 'whisper needs at least one thread'),
      _threads = threads,
      _useGpu = useGpu;

  final int _threads;
  final bool _useGpu;

  Isolate? _isolate;
  Future<SendPort>? _spawning;
  ReceivePort? _exit;
  final Set<Completer<Object?>> _pending = {};
  _FfiSession? _open;

  Future<SendPort> _ensureWorker() => _spawning ??= () async {
    final ready = ReceivePort();
    final exit = _exit = ReceivePort();
    _isolate = await Isolate.spawn(_workerMain, ready.sendPort, onExit: exit.sendPort);
    // A worker that dies (a kill, a native crash) answers every open question
    // as a failure instead of leaving it waiting forever.
    exit.listen((_) {
      for (final pending in _pending.toList()) {
        pending.complete(const _Failure(WhisperRuntimeError.runFailed, 'the worker ended'));
      }
      _pending.clear();
    });
    final port = await ready.first as SendPort;
    ready.close();
    return port;
  }();

  Future<T> _ask<T>(_Request request) async {
    final worker = await _ensureWorker();
    final reply = ReceivePort();
    final answer = Completer<Object?>();
    _pending.add(answer);
    reply.listen((message) {
      if (!answer.isCompleted) answer.complete(message);
    });
    worker.send((request, reply.sendPort));
    try {
      final result = await answer.future;
      if (result is _Failure) throw WhisperRuntimeException(result.error, result.message);
      return result as T;
    } finally {
      _pending.remove(answer);
      reply.close();
    }
  }

  @override
  Future<WhisperSession> load(File model) async {
    if (_open != null) throw StateError('a session is open');
    final session = _open = _FfiSession(this);
    try {
      await _ask<void>(_Load(model.path, _useGpu));
    } catch (_) {
      _open = null;
      calloc.free(session._abort);
      rethrow;
    }
    return session;
  }

  @override
  Future<void> dispose() async {
    final open = _open;
    if (open != null) await open.close();
    // A spawn still in flight would otherwise outlive the kill.
    await _spawning?.then((_) {}, onError: (Object _) {});
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _spawning = null;
    _exit?.close();
    _exit = null;
  }
}

class _FfiSession implements WhisperSession {
  _FfiSession(this._runtime) : _abort = calloc<Int32>();

  final FfiWhisperRuntime _runtime;
  final Pointer<Int32> _abort;
  Future<void>? _closing;

  @override
  Future<List<WhisperSegment>> run(File pcm, {required String language}) {
    if (_closing != null) throw StateError('session closed');
    _abort.value = 0;
    return _runtime._ask<List<WhisperSegment>>(
      _Run(pcm.path, language, _runtime._threads, _abort.address),
    );
  }

  @override
  void abort() {
    if (_closing == null) _abort.value = 1;
  }

  @override
  Future<void> close() => _closing ??= () async {
    // A run the caller left in flight ends early; the close queues behind it
    // on the worker either way.
    _abort.value = 1;
    if (identical(_runtime._open, this)) _runtime._open = null;
    try {
      await _runtime._ask<void>(const _Close());
    } finally {
      calloc.free(_abort);
    }
  }();
}

sealed class _Request {
  const _Request();
}

final class _Load extends _Request {
  const _Load(this.path, this.useGpu);

  final String path;
  final bool useGpu;
}

final class _Run extends _Request {
  const _Run(this.pcmPath, this.language, this.threads, this.abortAddress);

  final String pcmPath;
  final String language;
  final int threads;
  final int abortAddress;
}

final class _Close extends _Request {
  const _Close();
}

final class _Failure {
  const _Failure(this.error, [this.message]);

  final WhisperRuntimeError error;
  final String? message;
}

void _workerMain(SendPort home) {
  final inbox = ReceivePort();
  home.send(inbox.sendPort);
  final worker = _Worker();
  inbox.listen((message) {
    final (request, reply) = message as (_Request, SendPort);
    Object? answer;
    try {
      answer = switch (request) {
        _Load(:final path, :final useGpu) => worker.load(path, useGpu),
        _Run(:final pcmPath, :final language, :final threads, :final abortAddress) => worker.run(
          pcmPath,
          language,
          threads,
          abortAddress,
        ),
        _Close() => worker.close(),
      };
    } catch (e) {
      answer = _Failure(
        request is _Load ? WhisperRuntimeError.loadFailed : WhisperRuntimeError.runFailed,
        '$e',
      );
    }
    reply.send(answer);
  });
}

/// The worker isolate's state: the shim and the one context it holds.
class _Worker {
  final WhisperShim shim = WhisperShim();
  Pointer<Void> context = nullptr;

  Object? load(String path, bool useGpu) {
    close();
    final cPath = path.toNativeUtf8();
    try {
      context = shim.open(cPath, useGpu ? 1 : 0);
    } finally {
      calloc.free(cPath);
    }
    return context == nullptr ? const _Failure(WhisperRuntimeError.loadFailed, 'open') : null;
  }

  Object? close() {
    if (context != nullptr) shim.close(context);
    context = nullptr;
    return null;
  }

  Object run(String pcmPath, String language, int threads, int abortAddress) {
    if (context == nullptr) return const _Failure(WhisperRuntimeError.badArgs, 'no model loaded');
    final file = File(pcmPath);
    final count = file.lengthSync() ~/ 4;
    if (count == 0) return const <WhisperSegment>[];
    final samples = calloc<Float>(count);
    final cLanguage = language.toNativeUtf8();
    try {
      // Read straight into native memory: a long take is many megabytes and
      // must not sit in the Dart heap as well.
      final raf = file.openSync();
      try {
        raf.readIntoSync(samples.asTypedList(count).buffer.asUint8List(0, count * 4));
      } finally {
        raf.closeSync();
      }
      final rc = shim.run(
        context,
        samples,
        count,
        cLanguage,
        threads,
        Pointer<Int32>.fromAddress(abortAddress),
      );
      if (rc == WhisperShimCode.aborted) return const _Failure(WhisperRuntimeError.aborted);
      if (rc == WhisperShimCode.badArgs) return const _Failure(WhisperRuntimeError.badArgs, 'run');
      if (rc != WhisperShimCode.ok) return _Failure(WhisperRuntimeError.runFailed, 'code $rc');
      return _segments();
    } finally {
      calloc.free(samples);
      calloc.free(cLanguage);
    }
  }

  List<WhisperSegment> _segments() {
    final count = shim.segmentCount(context);
    final text = calloc<Pointer<Utf8>>();
    final t0 = calloc<Int64>();
    final t1 = calloc<Int64>();
    final confidence = calloc<Float>();
    try {
      return [
        for (var i = 0; i < count; i++)
          if (shim.segment(context, i, text, t0, t1, confidence) == WhisperShimCode.ok)
            WhisperSegment.centiseconds(
              text: text.value.toDartString(),
              start: t0.value,
              end: t1.value,
              confidence: confidence.value,
            ),
      ];
    } finally {
      calloc.free(text);
      calloc.free(t0);
      calloc.free(t1);
      calloc.free(confidence);
    }
  }
}
