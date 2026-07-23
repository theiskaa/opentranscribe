import 'package:flutter/foundation.dart';

/// A finished recording: a kept audio file on disk and how long it runs.
@immutable
class Recording {
  const Recording({required this.path, required this.duration});

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
/// resumed state.
enum CaptureStatus { recording, interrupted, stopped }

/// Microphone permission state, distinct from speech-recognition authorization
/// (which the engine reports through [Availability]). Two separate iOS grants.
enum PermissionStatus { granted, denied, restricted, undetermined }
