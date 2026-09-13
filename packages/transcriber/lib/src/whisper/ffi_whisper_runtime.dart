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
/// flag and the progress percent live in native memory owned by this
/// isolate, so a cancel reaches the worker mid-run and its progress reaches
/// back, without a message. [threads] is asked at every run's start and
/// holds until that run ends; [useGpu] is handed to whisper's context init
/// as is.
class FfiWhisperRuntime implements WhisperRuntime {
  FfiWhisperRuntime({required int Function() threads, bool useGpu = true})
    : _threads = threads,
      _useGpu = useGpu;

  final int Function() _threads;
  final bool _useGpu;

  static const _progressPoll = Duration(milliseconds: 200);

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
      session._free();
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
  _FfiSession(this._runtime) : _abort = calloc<Int32>(), _progress = calloc<Int32>();

  final FfiWhisperRuntime _runtime;
  final Pointer<Int32> _abort;
  final Pointer<Int32> _progress;
  Future<void>? _closing;
  bool _freed = false;

  // A release closes a loading session behind its load, and a load that then
  // fails frees it too; a second free would corrupt the heap.
  void _free() {
    if (_freed) return;
    _freed = true;
    calloc.free(_abort);
    calloc.free(_progress);
  }

  @override
  Future<List<WhisperSegment>> run(
    File pcm, {
    required String language,
    void Function(double fraction)? onProgress,
  }) async {
    if (_closing != null) throw StateError('session closed');
    _abort.value = 0;
    _progress.value = 0;
    final threads = _runtime._threads();
    assert(threads >= 1, 'whisper needs at least one thread');
    final answer = _runtime._ask<List<WhisperSegment>>(
      _Run(pcm.path, language, threads, _abort.address, _progress.address),
    );
    if (onProgress == null) return answer;
    var reported = 0;
    final poll = Timer.periodic(FfiWhisperRuntime._progressPoll, (_) {
      final percent = _progress.value;
      if (percent <= reported) return;
      reported = percent;
      onProgress(percent / 100);
    });
    try {
      return await answer;
    } finally {
      poll.cancel();
    }
  }

  @override
  Future<List<double>> detect(File pcm, {required List<String> codes}) {
    if (_closing != null) throw StateError('session closed');
    return _runtime._ask<List<double>>(_Detect(pcm.path, codes, _runtime._threads()));
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
      _free();
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
  const _Run(this.pcmPath, this.language, this.threads, this.abortAddress, this.progressAddress);

  final String pcmPath;
  final String language;
  final int threads;
  final int abortAddress;
  final int progressAddress;
}

final class _Detect extends _Request {
  const _Detect(this.pcmPath, this.codes, this.threads);

  final String pcmPath;
  final List<String> codes;
  final int threads;
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
        _Run(
          :final pcmPath,
          :final language,
          :final threads,
          :final abortAddress,
          :final progressAddress,
        ) =>
          worker.run(pcmPath, language, threads, abortAddress, progressAddress),
        _Detect(:final pcmPath, :final codes, :final threads) => worker.detect(
          pcmPath,
          codes,
          threads,
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

  /// [pcmPath]'s samples, read straight into native memory: a long take is
  /// many megabytes and must not sit in the Dart heap as well. Null for an
  /// empty file; the caller frees the pointer.
  (Pointer<Float>, int)? _readSamples(String pcmPath) {
    final file = File(pcmPath);
    final count = file.lengthSync() ~/ sizeOf<Float>();
    if (count == 0) return null;
    final samples = calloc<Float>(count);
    try {
      final raf = file.openSync();
      try {
        raf.readIntoSync(samples.asTypedList(count).buffer.asUint8List(0, count * sizeOf<Float>()));
      } finally {
        raf.closeSync();
      }
    } catch (_) {
      calloc.free(samples);
      rethrow;
    }
    return (samples, count);
  }

  Object run(String pcmPath, String language, int threads, int abortAddress, int progressAddress) {
    if (context == nullptr) return const _Failure(WhisperRuntimeError.badArgs, 'no model loaded');
    final read = _readSamples(pcmPath);
    if (read == null) return const <WhisperSegment>[];
    final (samples, count) = read;
    final cLanguage = language.toNativeUtf8();
    try {
      final rc = shim.run(
        context,
        samples,
        count,
        cLanguage,
        threads,
        Pointer<Int32>.fromAddress(abortAddress),
        Pointer<Int32>.fromAddress(progressAddress),
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

  Object detect(String pcmPath, List<String> codes, int threads) {
    if (context == nullptr) return const _Failure(WhisperRuntimeError.badArgs, 'no model loaded');
    final read = codes.isEmpty ? null : _readSamples(pcmPath);
    if (read == null) return List<double>.filled(codes.length, 0);
    final (samples, count) = read;
    final names = calloc<Pointer<Utf8>>(codes.length);
    final odds = calloc<Float>(codes.length);
    try {
      for (var i = 0; i < codes.length; i++) {
        names[i] = codes[i].toNativeUtf8();
      }
      final rc = shim.detect(context, samples, count, threads, names, codes.length, odds);
      if (rc == WhisperShimCode.badArgs) {
        return const _Failure(WhisperRuntimeError.badArgs, 'detect');
      }
      if (rc != WhisperShimCode.ok) return _Failure(WhisperRuntimeError.runFailed, 'code $rc');
      return [for (var i = 0; i < codes.length; i++) odds[i]];
    } finally {
      for (var i = 0; i < codes.length; i++) {
        if (names[i] != nullptr) calloc.free(names[i]);
      }
      calloc.free(names);
      calloc.free(odds);
      calloc.free(samples);
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
