import 'dart:async';

import 'package:transcriber/src/audio/audio_composer.dart';
import 'package:transcriber/src/audio/recording.dart';
import 'package:transcriber/src/transcribe/transcription_exception.dart';

/// Deterministic [AudioComposer] for tests. Starts derive from [durations] (a
/// per-name map, [defaultDuration] for names not in it) so a test can assert
/// offset math against the numbers its recorder fake reports; [starts] and
/// [duration] override the derived values when a test needs them to disagree
/// with any stored duration. [gate] holds a merge open until it completes and
/// may be reset between calls for race tests; [throwOnConcatenate] fails every
/// call, leaving nothing behind like the real one.
class FakeAudioComposer implements AudioComposer {
  FakeAudioComposer({
    this.name = 'otr-merged.m4a',
    Map<String, Duration> durations = const {},
    this.defaultDuration = const Duration(seconds: 2),
    this.starts,
    this.duration,
    this.throwOnConcatenate = false,
    this.gate,
  }) : durations = Map.of(durations);

  final String name;
  final Map<String, Duration> durations;
  final Duration defaultDuration;
  final List<Duration>? starts;
  final Duration? duration;
  final bool throwOnConcatenate;
  Future<void>? gate;

  final List<List<String>> calls = [];

  int _serial = 0;

  @override
  Future<Composition> concatenate(List<String> names) {
    if (names.length < 2) throw ArgumentError.value(names, 'names', 'two or more required');
    if (names.any((n) => n.isEmpty || n.contains('/'))) {
      throw ArgumentError.value(names, 'names', 'bare filenames required');
    }
    return _run(List.unmodifiable(names));
  }

  Future<Composition> _run(List<String> names) async {
    calls.add(names);
    final held = gate;
    if (held != null) await held;
    if (throwOnConcatenate) throw const AudioComposeFailed('fake merge failed', 'compose_failed');
    final derived = <Duration>[];
    var total = Duration.zero;
    for (final n in names) {
      derived.add(total);
      total += durations[n] ?? defaultDuration;
    }
    // Every call lands a fresh name so a repeat cannot alias the last.
    final dot = name.lastIndexOf('.');
    final stem = dot < 0 ? name : name.substring(0, dot);
    final ext = dot < 0 ? '' : name.substring(dot);
    final out = _serial == 0 ? name : '$stem-$_serial$ext';
    _serial++;
    return Composition(name: out, duration: duration ?? total, starts: starts ?? derived);
  }
}
