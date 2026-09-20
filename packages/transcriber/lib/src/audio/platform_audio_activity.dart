import 'dart:io';

import 'package:flutter/services.dart';

import 'package:transcriber/src/audio/audio_activity.dart';

// Must match AudioCapture.swift.
const _controlChannel = 'transcriber/audio';

/// The iOS-native [AudioActivity]: AudioDecode.swift reads the slice at
/// 16 kHz and answers its voiced ranges on the recorder's channel. Any
/// failure, a malformed reply included, answers null.
class PlatformAudioActivity implements AudioActivity {
  PlatformAudioActivity({MethodChannel? methods})
    : _methods = methods ?? const MethodChannel(_controlChannel);

  final MethodChannel _methods;

  @override
  Future<List<VoicedRange>?> voiced(File audio, {Duration? start, Duration? end}) async {
    if (audio.path.isEmpty || (start?.isNegative ?? false) || (end?.isNegative ?? false)) {
      return null;
    }
    try {
      final result = await _methods.invokeMapMethod<String, dynamic>('voicedRanges', {
        'path': audio.path,
        if (start != null) 'startMs': start.inMilliseconds,
        if (end != null) 'endMs': end.inMilliseconds,
      });
      final ranges = result?['ranges'];
      if (ranges is! List) return null;
      final voiced = <VoicedRange>[];
      for (final range in ranges) {
        if (range case [final int startMs, final int endMs] when startMs <= endMs) {
          voiced.add((start: Duration(milliseconds: startMs), end: Duration(milliseconds: endMs)));
        } else {
          return null;
        }
      }
      return voiced;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    } on TypeError {
      return null;
    }
  }
}
