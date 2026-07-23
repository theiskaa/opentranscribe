import 'package:opentranscribe/core/audio/recording.dart';

/// App-owned audio capture. Produces a kept file (via [Recording]) and a capture
/// lifecycle stream. It deliberately knows nothing about any transcription
/// engine: it captures and writes audio, nothing more.
///
/// A streaming engine taps the same native capture session directly, so no audio
/// crosses into Dart. The native implementation arrives later; the contract is
/// fixed here so the service and its tests can be built against it now.
abstract interface class AudioRecorder {
  /// Requests microphone permission if not already decided, and reports the result.
  Future<PermissionStatus> ensurePermission();

  /// Begins capture to a fresh file.
  Future<void> start();

  /// Capture lifecycle: recording, interruption, stopped.
  Stream<CaptureStatus> get status;

  /// Finalizes the file and returns its path and duration.
  Future<Recording> stop();
}
