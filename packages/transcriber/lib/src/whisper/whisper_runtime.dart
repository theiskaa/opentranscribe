import 'dart:io';

import 'package:flutter/foundation.dart';

/// One timed span whisper heard, relative to the samples it was handed.
@immutable
final class WhisperSegment {
  const WhisperSegment({
    required this.text,
    required this.start,
    required this.end,
    required this.confidence,
  });

  /// whisper times segments in centiseconds.
  WhisperSegment.centiseconds({
    required this.text,
    required int start,
    required int end,
    required this.confidence,
  }) : start = Duration(milliseconds: start * 10),
       end = Duration(milliseconds: end * 10);

  final String text;
  final Duration start;
  final Duration end;
  final double confidence;

  @override
  bool operator ==(Object other) =>
      other is WhisperSegment &&
      other.text == text &&
      other.start == start &&
      other.end == end &&
      other.confidence == confidence;

  @override
  int get hashCode => Object.hash(text, start, end, confidence);
}

/// Why a runtime call failed, as a kind the engine maps to its taxonomy.
enum WhisperRuntimeError { loadFailed, runFailed, aborted, badArgs }

/// A runtime failure, typed by [WhisperRuntimeError] so the engine can map it
/// without parsing text.
final class WhisperRuntimeException implements Exception {
  const WhisperRuntimeException(this.error, [this.message]);

  final WhisperRuntimeError error;
  final String? message;

  @override
  String toString() =>
      'WhisperRuntimeException(${error.name}${message == null ? '' : ': $message'})';
}

/// A loaded model. Guarantees a caller may rely on: [run] reads a
/// [DecodedPcm] file (raw 16 kHz mono 32-bit float, no header) and answers
/// whisper's segments in order, an empty list when it heard nothing; one run
/// at a time per session, the caller serializes; [onProgress] hears the run's
/// fraction in order, never after the future settles; [abort] ends the run in
/// flight (it fails as [WhisperRuntimeError.aborted]), is safe when nothing
/// runs, and does not carry into the next run; after [close] nothing else may
/// be called.
abstract interface class WhisperSession {
  Future<List<WhisperSegment>> run(
    File pcm, {
    required String language,
    void Function(double fraction)? onProgress,
  });

  void abort();

  Future<void> close();
}

/// Loads model files into sessions. [load] fails as
/// [WhisperRuntimeError.loadFailed] when the file cannot become a context (a
/// missing or corrupt file, no memory). One session at a time: loading again
/// while one is open is the caller's mistake. [dispose] ends any session and
/// releases everything the runtime holds; the next [load] starts fresh.
abstract interface class WhisperRuntime {
  Future<WhisperSession> load(File model);

  Future<void> dispose();
}
