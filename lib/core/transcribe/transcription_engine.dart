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

/// One language model's own state on the device. Ordered from worst to best:
/// the platform has nothing to serve, the asset is downloadable, a download is
/// pending (possibly waiting for conditions, across launches), or it is ready.
enum ModelAssetStatus { unsupported, supported, downloading, installed }

/// One language's model state along the two platform axes a management UI
/// needs: the asset's own [status], and [reserved], whether THIS app may use
/// it right now (a model can be installed system-wide yet unusable here until
/// re-reserved). [resolvedTag] is the supported tag the engine canonicalized
/// the request to (de-AT answering as de-DE), so callers key follow-up actions
/// on what the engine will actually use.
@immutable
final class LocaleModelStatus {
  const LocaleModelStatus({
    required this.status,
    required this.reserved,
    required this.resolvedTag,
  });

  final ModelAssetStatus status;
  final bool reserved;
  final String resolvedTag;

  bool get isReady => status == ModelAssetStatus.installed && reserved;

  @override
  bool operator ==(Object other) =>
      other is LocaleModelStatus &&
      other.status == status &&
      other.reserved == reserved &&
      other.resolvedTag == resolvedTag;

  @override
  int get hashCode => Object.hash(status, reserved, resolvedTag);
}

/// How many languages this app may hold usable at once, and which it holds
/// now. [max] comes from the platform at runtime (it varies by device
/// storage). 0 is the whole degraded family in one value: no reservation
/// concept exists (pre-26, engines without managed models) OR the engine
/// could not answer. Renderers show no cap then; consumers that would ACT on
/// reserved-ness (remove, evict) must treat 0 as "offer nothing", since the
/// per-row reserved flag defaults to usable there.
@immutable
final class ReservationInfo {
  const ReservationInfo({required this.max, required this.reservedTags});

  final int max;
  final List<String> reservedTags;

  @override
  bool operator ==(Object other) =>
      other is ReservationInfo && other.max == max && listEquals(other.reservedTags, reservedTags);

  @override
  int get hashCode => Object.hash(max, Object.hashAll(reservedTags));
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

  /// The BCP-47 tags this engine can transcribe on-device, for a language picker.
  /// Membership means supported, not installed ([ManagedModelEngine.isModelInstalled]
  /// answers readiness). Engines may accept near variants of a listed tag (de-AT
  /// resolving to de-DE); an unlisted language fails honestly via
  /// [checkAvailability], never by silently transcribing as something else. A
  /// preflight: implementations never throw, returning an empty list when the
  /// engine cannot answer.
  Future<List<String>> supportedLocales();

  /// Transcribes a kept audio file, or just the [start]..[end] slice of it
  /// (null bounds = the file's own edges). Ranges are what let a session
  /// spoken in several languages batch each span with its own model. An
  /// engine that cannot honor a range must FAIL the call, never silently
  /// transcribe the whole file: callers fall back on failure, and a whole
  /// file answered as a slice would duplicate text across spans. Segment
  /// timings in the result are relative to the SLICE; the caller offsets.
  Future<Transcript> transcribeFile(
    File audio, {
    required String localeId,
    Duration? start,
    Duration? end,
  });
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
  /// One more contract clause, load-bearing for mid-take language switches: a
  /// NEW listen must succeed while a previous live stream's cancel is still
  /// completing (implementations serialize or isolate their transports), and
  /// a consumer cancel must complete even when the stream will never emit
  /// again. Callers rely on both without awaiting the old stream's teardown.
  Stream<TranscriptEvent> transcribeLive({required String localeId});
}

/// An engine that can abort its in-flight batch transcriptions. The service
/// calls this when a batch outlives its timeout, so an abandoned native task
/// does not keep holding the recognizer. Cancelling must be safe at any time,
/// including when nothing is in flight, and must never affect live streaming.
abstract interface class CancellableBatchEngine {
  Future<void> cancelBatches();
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
  /// Overlapping calls for DIFFERENT locales are allowed (a per-language UI
  /// invites them); an implementation whose transport is single-flight must
  /// serialize them itself rather than let a later call wedge an earlier one.
  /// Callers still promise not to run two installs for the SAME locale.
  Stream<ModelInstallProgress> installModel({required String localeId});

  /// The tags whose models are downloaded on this DEVICE. Assets are shared
  /// system-wide, so this can include languages another app or OS feature
  /// installed. Installed does not mean usable by this app; [localeStatus]
  /// carries that second axis. Preflight: never throws, empty when the engine
  /// cannot answer.
  Future<List<String>> installedLocales();

  /// Fine-grained state for one language. Preflight: never throws; an engine
  /// that cannot answer reports downloadable-but-not-ready rather than lying
  /// in either direction.
  Future<LocaleModelStatus> localeStatus({required String localeId});

  /// Releases this app's claim on a language's model. The platform may keep
  /// the shared asset on disk and remove it on its own schedule; this only
  /// ends THIS app's use of the language until it is installed again. Returns
  /// whether a claim was actually released.
  Future<bool> removeLanguage({required String localeId});

  /// The platform's language cap and this app's current holdings, for a
  /// management UI to render honestly. Preflight: never throws.
  Future<ReservationInfo> reservationInfo();
}
