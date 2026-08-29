import 'package:flutter/foundation.dart';

/// A finished recording: a kept audio file on disk and how long it runs.
@immutable
final class Recording {
  const Recording({required this.path, required this.duration});

  /// The file reference: a bare filename from the native recorder (resolved
  /// against [AudioRecorder.recordingsDirectory]), or an absolute path from a
  /// test double. Consumers resolve, never assume, the shape.
  final String path;
  final Duration duration;

  @override
  bool operator ==(Object other) =>
      other is Recording && other.path == path && other.duration == duration;

  @override
  int get hashCode => Object.hash(path, duration);
}

/// Lifecycle of a capture session, so callers can react to interruptions. An
/// interruption ends the capture (there is no auto-resume), so there is no
/// resumed state; a user resume after [paused] re-emits [recording].
enum CaptureStatus { recording, paused, interrupted, stopped }

/// Microphone permission state, distinct from speech-recognition authorization
/// (which the engine reports through [Availability]). Two separate platform grants.
enum PermissionStatus { granted, denied, restricted, undetermined }

/// The output of an [AudioComposer] merge.
@immutable
final class Composition {
  Composition({required this.name, required this.duration, required List<Duration> starts})
    : starts = List.unmodifiable(starts);

  /// A bare filename in the recordings directory.
  final String name;
  final Duration duration;

  /// Where each input begins in the output, as the writer measured it; one per
  /// input, in order, `starts.first` always zero.
  final List<Duration> starts;

  @override
  bool operator ==(Object other) =>
      other is Composition &&
      other.name == name &&
      other.duration == duration &&
      listEquals(other.starts, starts);

  @override
  int get hashCode => Object.hash(name, duration, Object.hashAll(starts));
}
