/// The closed set of transcription failures. Native error codes map onto these
/// so the app reasons about failures by type, not by string. Empty or silent
/// audio is NOT a failure: it is an empty transcript.
sealed class TranscriptionException implements Exception {
  const TranscriptionException([this.message]);

  final String? message;

  @override
  String toString() => message == null ? '$runtimeType' : '$runtimeType: $message';
}

/// Microphone or speech recognition authorization was denied.
class PermissionDenied extends TranscriptionException {
  const PermissionDenied([super.message]);
}

/// On-device recognition is unavailable and we refuse to use a server recognizer.
/// This also covers a locale with no installed on-device model.
class OnDeviceUnavailable extends TranscriptionException {
  const OnDeviceUnavailable([super.message]);
}

/// Audio capture failed to start or write. [code] carries the native error code
/// (e.g. no_input vs capture_failed) so callers can branch without matching text.
class CaptureFailed extends TranscriptionException {
  const CaptureFailed([super.message, this.code]);

  final String? code;

  @override
  String toString() => code == null ? super.toString() : '${super.toString()} ($code)';
}

/// The engine's on-device model could not be downloaded or installed. Distinct from
/// [TranscriptionFailed]: almost always transient (network), with a different retry
/// story than a broken transcription.
class ModelInstallFailed extends TranscriptionException {
  const ModelInstallFailed([super.message]);
}

/// The engine failed to produce a transcript.
class TranscriptionFailed extends TranscriptionException {
  const TranscriptionFailed([super.message]);
}
