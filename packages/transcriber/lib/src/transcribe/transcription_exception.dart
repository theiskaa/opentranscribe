import 'package:transcriber/src/transcribe/transcription_engine.dart';

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
/// story than a broken transcription. [assetStatus] is the asset's state just
/// before the attempt, when the engine could report it: a stuck download, a
/// language the platform has no asset for, and an ordinary network failure all
/// deserve different words in the UI.
class ModelInstallFailed extends TranscriptionException {
  const ModelInstallFailed([super.message, this.assetStatus]);

  final ModelAssetStatus? assetStatus;
}

/// The platform's per-app language cap is full: installing another language
/// needs one of [reservedTags] removed first. Its own type because the fix is
/// an eviction choice by the user, not a retry.
class ReservationCapReached extends TranscriptionException {
  const ReservationCapReached(this.reservedTags, [String? message]) : super(message);

  final List<String> reservedTags;
}

/// The engine failed to produce a transcript.
class TranscriptionFailed extends TranscriptionException {
  const TranscriptionFailed([super.message]);
}

/// An audio merge could not produce its file. [code] carries the native reason
/// (a missing or unreadable input versus a write failure) for callers that
/// branch; every case leaves the inputs untouched and nothing partial behind.
class AudioComposeFailed extends TranscriptionException {
  const AudioComposeFailed([super.message, this.code]);

  final String? code;

  @override
  String toString() => code == null ? super.toString() : '${super.toString()} ($code)';
}
