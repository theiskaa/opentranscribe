import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:opentranscribe/core/transcribe/transcript.dart';
import 'package:opentranscribe/core/transcribe/transcript_event.dart';

/// Why an engine can or cannot transcribe right now. The failing values correspond
/// to [TranscriptionException] subtypes, so a preflight probe and a runtime failure
/// name the same condition the same way.
enum AvailabilityStatus { available, permissionDenied, onDeviceUnavailable }

@immutable
class Availability {
  const Availability(this.status, {this.detail});

  const Availability.available() : status = AvailabilityStatus.available, detail = null;

  final AvailabilityStatus status;
  final String? detail;

  bool get isAvailable => status == AvailabilityStatus.available;

  @override
  bool operator ==(Object other) =>
      other is Availability && other.status == status && other.detail == detail;

  @override
  int get hashCode => Object.hash(status, detail);
}

/// The one boundary the app talks to. Batch (file -> transcript) is universal: it
/// powers re-transcription and works for every engine, streaming or not. Nothing in
/// the app hard-codes the identity of the engine underneath.
abstract interface class TranscriptionEngine {
  String get id;

  /// Whether this engine runs entirely on-device. The app refuses any engine that
  /// answers false, so nothing can quietly route audio off the phone.
  bool get onDeviceOnly;

  /// Preflight probe of whether transcription can run for [localeId] right now. A
  /// seam for a "recognition unavailable" UI; implemented but not yet called.
  Future<Availability> checkAvailability({required String localeId});

  /// Transcribes a kept audio file. The re-transcription seam.
  Future<Transcript> transcribeFile(File audio, {required String localeId});
}

/// An engine that also produces live partial/final text while capture runs. Apple
/// Speech implements this; a batch-only engine like whisper.cpp does not. The
/// stream emits partials as you speak, then one final event, then closes when
/// capture stops. The audio stays with the native capture session: no audio
/// crosses this boundary, only text events do. Implementing this interface IS the
/// streaming capability; there is no separate flag.
abstract interface class StreamingTranscriptionEngine implements TranscriptionEngine {
  Stream<TranscriptEvent> transcribeLive({required String localeId});
}
