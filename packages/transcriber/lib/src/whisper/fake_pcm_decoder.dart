import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:transcriber/src/transcribe/transcription_exception.dart';
import 'package:transcriber/src/whisper/pcm_decoder.dart';

/// One decode request as the fake saw it.
final class DecodeCall {
  const DecodeCall({required this.path, this.start, this.end});

  final String path;
  final Duration? start;
  final Duration? end;
}

/// Deterministic [PcmDecoder] for tests. Writes a real file of silent samples
/// under [scratch] so a caller's cleanup can be observed; its length is
/// [framesPerSecond] times the slice's seconds ([defaultDuration] when the
/// slice has no end), so a test can assert what the runtime was handed.
/// [gate] holds a decode open until it completes; [throwOnDecode] fails every
/// call with the given code (mutable, so a test can change the failure between
/// calls), leaving nothing behind like the real one.
class FakePcmDecoder implements PcmDecoder {
  FakePcmDecoder({
    required this.scratch,
    this.defaultDuration = const Duration(seconds: 2),
    this.framesPerSecond = DecodedPcm.sampleRate,
    this.throwOnDecode,
    this.gate,
  });

  final Directory scratch;
  final Duration defaultDuration;
  final int framesPerSecond;

  String? throwOnDecode;
  Future<void>? gate;

  final List<DecodeCall> calls = [];
  final List<File> written = [];

  int _serial = 0;

  @override
  Future<DecodedPcm> decode(File audio, {Duration? start, Duration? end}) {
    if (audio.path.isEmpty) throw ArgumentError.value(audio, 'audio', 'path required');
    if (start != null && start.isNegative) throw ArgumentError.value(start, 'start', 'negative');
    if (end != null && end.isNegative) throw ArgumentError.value(end, 'end', 'negative');
    return _run(audio, start, end);
  }

  Future<DecodedPcm> _run(File audio, Duration? start, Duration? end) async {
    calls.add(DecodeCall(path: audio.path, start: start, end: end));
    final held = gate;
    if (held != null) await held;
    final code = throwOnDecode;
    if (code != null) throw PcmDecodeFailed('fake decode failed', code);
    final from = start ?? Duration.zero;
    final to = end ?? from + defaultDuration;
    if (to <= from) throw const PcmDecodeFailed('slice holds no frames', PcmDecodeFailed.empty);
    final frames = (to - from).inMilliseconds * framesPerSecond ~/ 1000;
    await scratch.create(recursive: true);
    final file = File('${scratch.path}/otr-fake-${_serial++}.pcm');
    await file.writeAsBytes(Uint8List(frames * 4), flush: true);
    written.add(file);
    return DecodedPcm(file: file, frames: frames);
  }
}
