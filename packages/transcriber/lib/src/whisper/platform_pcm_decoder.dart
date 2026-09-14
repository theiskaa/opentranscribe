import 'dart:io';

import 'package:flutter/services.dart';

import 'package:transcriber/src/transcribe/transcription_exception.dart';
import 'package:transcriber/src/whisper/pcm_decoder.dart';

// Must match AudioCapture.swift.
const _controlChannel = 'transcriber/audio';

/// The iOS-native [PcmDecoder]: AVAudioFile plus AVAudioConverter on the
/// recorder's channel. Calls are chained so two decodes never run at once;
/// channel failures map to [PcmDecodeFailed], never a raw PlatformException.
class PlatformPcmDecoder implements PcmDecoder {
  PlatformPcmDecoder({MethodChannel? methods})
    : _methods = methods ?? const MethodChannel(_controlChannel);

  final MethodChannel _methods;
  Future<void> _chain = Future<void>.value();

  @override
  Future<DecodedPcm> decode(File audio, {Duration? start, Duration? end}) {
    if (audio.path.isEmpty) throw ArgumentError.value(audio, 'audio', 'path required');
    if (start != null && start.isNegative) throw ArgumentError.value(start, 'start', 'negative');
    if (end != null && end.isNegative) throw ArgumentError.value(end, 'end', 'negative');
    final run = _chain.then((_) => _invoke(audio, start, end));
    // The chain only sequences; one failure must not poison every later call.
    _chain = run.then((_) {}, onError: (Object _) {});
    return run;
  }

  Future<DecodedPcm> _invoke(File audio, Duration? start, Duration? end) => _typed(() async {
    final result = await _methods.invokeMapMethod<String, dynamic>('decodePcm', {
      'path': audio.path,
      if (start != null) 'startMs': start.inMilliseconds,
      if (end != null) 'endMs': end.inMilliseconds,
    });
    final path = result?['path'] as String?;
    final frames = result?['frames'] as int?;
    if (path == null || path.isEmpty || frames == null || frames < 0) {
      throw const PcmDecodeFailed('malformed reply', PcmDecodeFailed.failed);
    }
    return DecodedPcm(file: File(path), frames: frames);
  });

  @override
  Future<Duration> length(File audio) {
    if (audio.path.isEmpty) throw ArgumentError.value(audio, 'audio', 'path required');
    return _typed(() async {
      final result = await _methods.invokeMapMethod<String, dynamic>('pcmLength', {
        'path': audio.path,
      });
      final ms = result?['ms'] as int?;
      if (ms == null || ms < 0) {
        throw const PcmDecodeFailed('malformed reply', PcmDecodeFailed.failed);
      }
      return Duration(milliseconds: ms);
    });
  }

  Future<T> _typed<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on PlatformException catch (e) {
      throw PcmDecodeFailed(e.message, e.code);
    } on MissingPluginException catch (e) {
      throw PcmDecodeFailed(e.message);
    } on TypeError {
      throw const PcmDecodeFailed('malformed reply', PcmDecodeFailed.failed);
    }
  }
}
