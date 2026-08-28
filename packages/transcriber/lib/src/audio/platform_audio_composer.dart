import 'package:flutter/services.dart';

import 'package:transcriber/src/audio/audio_composer.dart';
import 'package:transcriber/src/audio/recording.dart';
import 'package:transcriber/src/transcribe/transcription_exception.dart';

// Must match AudioCapture.swift.
const _controlChannel = 'transcriber/audio';

/// The iOS-native [AudioComposer]: decode-and-rewrite through AVAudioFile on
/// the recorder's channel. Calls are chained so two merges never write at once;
/// channel failures map to [AudioComposeFailed], never a raw PlatformException.
class PlatformAudioComposer implements AudioComposer {
  PlatformAudioComposer({MethodChannel? methods})
    : _methods = methods ?? const MethodChannel(_controlChannel);

  final MethodChannel _methods;
  Future<void> _chain = Future<void>.value();

  @override
  Future<Composition> concatenate(List<String> names) {
    if (names.length < 2) throw ArgumentError.value(names, 'names', 'two or more required');
    if (names.any((n) => n.isEmpty || n.contains('/'))) {
      throw ArgumentError.value(names, 'names', 'bare filenames required');
    }
    final run = _chain.then((_) => _invoke(List.unmodifiable(names)));
    // The chain only sequences; one failure must not poison every later call.
    _chain = run.then((_) {}, onError: (Object _) {});
    return run;
  }

  Future<Composition> _invoke(List<String> names) async {
    try {
      final result = await _methods.invokeMapMethod<String, dynamic>('concatenate', {
        'names': names,
      });
      final name = result?['name'] as String?;
      final durationMs = result?['durationMs'] as int?;
      final startsMs = (result?['startsMs'] as List<dynamic>?)?.cast<int>();
      // A defaulted reply would be an entry pointing at nothing; refuse it.
      if (name == null ||
          name.isEmpty ||
          durationMs == null ||
          startsMs == null ||
          startsMs.length != names.length ||
          startsMs.first != 0) {
        throw const AudioComposeFailed('malformed reply', 'compose_failed');
      }
      return Composition(
        name: name,
        duration: Duration(milliseconds: durationMs),
        starts: [for (final ms in startsMs) Duration(milliseconds: ms)],
      );
    } on PlatformException catch (e) {
      throw AudioComposeFailed(e.message, e.code);
    } on MissingPluginException catch (e) {
      throw AudioComposeFailed(e.message);
    }
  }
}
