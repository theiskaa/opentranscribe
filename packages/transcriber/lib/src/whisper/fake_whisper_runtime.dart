import 'dart:async';
import 'dart:io';

import 'package:transcriber/src/whisper/whisper_runtime.dart';

/// One run as the fake saw it.
final class RunCall {
  const RunCall({required this.pcmPath, required this.language, required this.modelPath});

  final String pcmPath;
  final String language;
  final String modelPath;
}

/// Deterministic [WhisperRuntime] for tests. Every run answers [segments];
/// [gate] holds a run open so a test can abort or interleave; [closeGate]
/// holds a close open; [loadGate] holds a load open; [failLoad] and [failRun]
/// fail typed; all are mutable
/// so a test flips them between runs. Records loads, runs, closes, aborts
/// and disposes, so a caller's session handling can be asserted.
class FakeWhisperRuntime implements WhisperRuntime {
  FakeWhisperRuntime({
    this.segments = const [
      WhisperSegment(
        text: 'hello',
        start: Duration.zero,
        end: Duration(seconds: 1),
        confidence: 0.9,
      ),
    ],
    this.failLoad = false,
    this.failRun = false,
    this.gate,
    this.closeGate,
    this.loadGate,
  });

  List<WhisperSegment> segments;
  bool failLoad;
  bool failRun;
  Future<void>? gate;
  Future<void>? closeGate;
  Future<void>? loadGate;

  final List<String> loads = [];
  final List<RunCall> runs = [];
  int closes = 0;
  int aborts = 0;
  int disposes = 0;
  FakeWhisperSession? open;

  @override
  Future<WhisperSession> load(File model) async {
    if (open != null) throw StateError('a session is open');
    loads.add(model.path);
    if (failLoad) throw const WhisperRuntimeException(WhisperRuntimeError.loadFailed, 'fake');
    final session = open = FakeWhisperSession(this, model.path);
    final held = loadGate;
    if (held != null) await held;
    return session;
  }

  @override
  Future<void> dispose() async {
    disposes++;
    await open?.close();
  }
}

/// The session [FakeWhisperRuntime.load] hands out; [closed] and [modelPath]
/// for assertions.
class FakeWhisperSession implements WhisperSession {
  FakeWhisperSession(this._runtime, this.modelPath);

  final FakeWhisperRuntime _runtime;
  final String modelPath;
  bool closed = false;
  bool _aborted = false;

  @override
  Future<List<WhisperSegment>> run(File pcm, {required String language}) async {
    if (closed) throw StateError('session closed');
    _aborted = false;
    _runtime.runs.add(RunCall(pcmPath: pcm.path, language: language, modelPath: modelPath));
    final held = _runtime.gate;
    if (held != null) await held;
    if (_aborted) throw const WhisperRuntimeException(WhisperRuntimeError.aborted);
    if (_runtime.failRun) {
      throw const WhisperRuntimeException(WhisperRuntimeError.runFailed, 'fake');
    }
    return _runtime.segments;
  }

  @override
  void abort() {
    _aborted = true;
    _runtime.aborts++;
  }

  @override
  Future<void> close() async {
    if (closed) return;
    closed = true;
    _aborted = true;
    final held = _runtime.closeGate;
    if (held != null) await held;
    _runtime.closes++;
    if (identical(_runtime.open, this)) _runtime.open = null;
  }
}
