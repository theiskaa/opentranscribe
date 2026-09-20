import 'dart:ffi';

import 'package:ffi/ffi.dart';

/// Result codes; must match otr_whisper.h.
abstract final class WhisperShimCode {
  static const int ok = 0;
  static const int aborted = 1;
  static const int badArgs = -1;
  static const int failed = -2;
  static const int outOfRange = -3;
}

typedef _VersionNative = Pointer<Utf8> Function();
typedef _OpenNative = Pointer<Void> Function(Pointer<Utf8> modelPath, Int32 useGpu);
typedef WhisperShimOpenDart = Pointer<Void> Function(Pointer<Utf8> modelPath, int useGpu);
typedef _CloseNative = Void Function(Pointer<Void> w);
typedef WhisperShimCloseDart = void Function(Pointer<Void> w);
typedef _RunNative =
    Int32 Function(
      Pointer<Void> w,
      Pointer<Float> samples,
      Int32 count,
      Pointer<Utf8> language,
      Int32 threads,
      Pointer<Int32> abortFlag,
      Pointer<Int32> progressOut,
    );
typedef WhisperShimRunDart =
    int Function(
      Pointer<Void> w,
      Pointer<Float> samples,
      int count,
      Pointer<Utf8> language,
      int threads,
      Pointer<Int32> abortFlag,
      Pointer<Int32> progressOut,
    );
typedef _SegmentCountNative = Int32 Function(Pointer<Void> w);
typedef WhisperShimSegmentCountDart = int Function(Pointer<Void> w);
typedef _SegmentNative =
    Int32 Function(
      Pointer<Void> w,
      Int32 index,
      Pointer<Pointer<Utf8>> text,
      Pointer<Int64> t0,
      Pointer<Int64> t1,
      Pointer<Float> confidence,
    );
typedef WhisperShimSegmentDart =
    int Function(
      Pointer<Void> w,
      int index,
      Pointer<Pointer<Utf8>> text,
      Pointer<Int64> t0,
      Pointer<Int64> t1,
      Pointer<Float> confidence,
    );

typedef _DetectNative =
    Int32 Function(
      Pointer<Void> w,
      Pointer<Float> samples,
      Int32 count,
      Int32 threads,
      Pointer<Pointer<Utf8>> codes,
      Int32 codeCount,
      Pointer<Float> oddsOut,
    );
typedef WhisperShimDetectDart =
    int Function(
      Pointer<Void> w,
      Pointer<Float> samples,
      int count,
      int threads,
      Pointer<Pointer<Utf8>> codes,
      int codeCount,
      Pointer<Float> oddsOut,
    );

/// Hand-written bindings for otr_whisper.h, the flat C surface the transcriber
/// plugin compiles over whisper.cpp. Symbols resolve lazily from the process
/// image by default, so a build that left the shim out fails at first use
/// with the symbol's name, not at construction.
final class WhisperShim {
  WhisperShim({DynamicLibrary? library}) : _library = library ?? DynamicLibrary.process();

  final DynamicLibrary _library;

  late final _VersionNative _version = _library.lookupFunction<_VersionNative, _VersionNative>(
    'otr_whisper_version',
  );
  late final WhisperShimOpenDart open = _library.lookupFunction<_OpenNative, WhisperShimOpenDart>(
    'otr_whisper_open',
  );
  late final WhisperShimCloseDart close = _library
      .lookupFunction<_CloseNative, WhisperShimCloseDart>('otr_whisper_close');
  late final WhisperShimRunDart run = _library.lookupFunction<_RunNative, WhisperShimRunDart>(
    'otr_whisper_run',
  );
  late final WhisperShimSegmentCountDart segmentCount = _library
      .lookupFunction<_SegmentCountNative, WhisperShimSegmentCountDart>('otr_whisper_n_segments');
  late final WhisperShimSegmentDart segment = _library
      .lookupFunction<_SegmentNative, WhisperShimSegmentDart>('otr_whisper_segment');

  late final WhisperShimDetectDart detect = _library
      .lookupFunction<_DetectNative, WhisperShimDetectDart>('otr_whisper_detect');

  String version() => _version().toDartString();
}
