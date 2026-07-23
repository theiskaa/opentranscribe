import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:opentranscribe/core/transcribe/transcript.dart';
import 'package:opentranscribe/core/transcribe/transcript_event.dart';

/// Why an engine can or cannot transcribe right now. The failing values correspond
/// to [TranscriptionException] subtypes, so a preflight probe and a runtime failure
/// name the same condition the same way.
enum AvailabilityStatus { available, permissionDenied, onDeviceUnavailable }

@immutable
final class Availability {
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

/// Progress of an on-device model download: [fraction] complete in [0,1], and
/// [done] once installed. Engine-neutral: whatever an engine must fetch to run
/// offline (an Apple asset today, a whisper model later) reports through this.
@immutable
final class ModelInstallProgress {
  const ModelInstallProgress({required this.fraction, required this.done});

  final double fraction;
  final bool done;

  @override
  bool operator ==(Object other) =>
      other is ModelInstallProgress && other.fraction == fraction && other.done == done;

  @override
  int get hashCode => Object.hash(fraction, done);
}

/// The one boundary the app talks to. Batch (file -> transcript) is universal: it
/// powers re-transcription and works for every engine, streaming or not. Nothing in
/// the app hard-codes the identity of the engine underneath.
abstract interface class TranscriptionEngine {
  String get id;

  /// Whether this engine runs entirely on-device. The app refuses any engine that
  /// answers false, so nothing can quietly route audio off the phone.
  bool get onDeviceOnly;

  /// Preflight probe of whether transcription can run for [localeId] at all. The
  /// probe itself downloads nothing; a managed engine fetches its model once on
  /// first use. Whether it is ready with no wait is the separate
  /// [ManagedModelEngine.isModelInstalled] question. A seam for a "recognition
  /// unavailable" UI.
  Future<Availability> checkAvailability({required String localeId});

  /// Transcribes a kept audio file. The re-transcription seam.
  Future<Transcript> transcribeFile(File audio, {required String localeId});
}

/// An engine that also produces live partial/final text while capture runs. Apple
/// Speech implements this; our planned whisper.cpp engine is batch-only. The
/// stream emits partials as you speak, then one final event after capture stops.
/// A degraded engine may emit nothing at all, so consumers must cancel their
/// subscription when capture ends rather than await the final event as a signal.
/// The audio stays with the native capture session: no audio crosses this
/// boundary, only text events do. Implementing this interface IS the streaming
/// capability; there is no separate flag.
abstract interface class StreamingTranscriptionEngine implements TranscriptionEngine {
  Stream<TranscriptEvent> transcribeLive({required String localeId});
}

/// An engine whose on-device model is downloaded and managed on the device. Apple
/// Speech implements this (its language assets); a future whisper.cpp engine would
/// too (its model file). An engine with no downloadable model does not implement it,
/// and callers treat that as "always installed". Capability by type, no flag.
abstract interface class ManagedModelEngine implements TranscriptionEngine {
  /// Whether the model for [localeId] is downloaded, so transcription runs now
  /// with no wait. Distinct from [checkAvailability], which reports whether the
  /// locale is supported at all (the probe itself downloads nothing).
  Future<bool> isModelInstalled({required String localeId});

  /// Downloads and installs the model for [localeId], streaming progress and ending
  /// with a [ModelInstallProgress.done] event. A no-op stream if already installed.
  /// Single-flight is the CALLER's promise: implementations may assume no two
  /// installs run concurrently and need not serialize them.
  Stream<ModelInstallProgress> installModel({required String localeId});
}
