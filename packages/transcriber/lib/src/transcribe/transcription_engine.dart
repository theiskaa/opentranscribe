import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:transcriber/src/transcribe/transcript.dart';
import 'package:transcriber/src/transcribe/transcript_event.dart';

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
/// offline (an Apple asset, a whisper model) reports through this.
/// [preparing] marks the work after the bytes arrived (unpacking, a one-time
/// compile) that no fraction measures and no cancel can end.
@immutable
final class ModelInstallProgress {
  const ModelInstallProgress({required this.fraction, required this.done, this.preparing = false});

  final double fraction;
  final bool done;
  final bool preparing;

  @override
  bool operator ==(Object other) =>
      other is ModelInstallProgress &&
      other.fraction == fraction &&
      other.done == done &&
      other.preparing == preparing;

  @override
  int get hashCode => Object.hash(fraction, done, preparing);
}

/// How good a downloadable model is, from worst to best, for a picker to word.
enum ModelQuality { basic, good, better, best, top }

/// One model a [ModelChoiceEngine] can run: what a picker renders. [bytes] is
/// the download's exact size; [peakMemoryBytes] what a run needs resident
/// whatever the audio's length, so a surface can dim a model this device
/// cannot hold. Presentation words belong to the app; the package carries
/// only the facts.
@immutable
final class ModelOption {
  const ModelOption({
    required this.id,
    required this.displayName,
    required this.bytes,
    required this.quality,
    required this.peakMemoryBytes,
    this.accelerationBytes = 0,
  });

  final String id;
  final String displayName;
  final int bytes;
  final ModelQuality quality;
  final int peakMemoryBytes;

  /// The extra download acceleration costs this model; zero for an engine
  /// without it.
  final int accelerationBytes;

  @override
  bool operator ==(Object other) =>
      other is ModelOption &&
      other.id == id &&
      other.displayName == displayName &&
      other.bytes == bytes &&
      other.quality == quality &&
      other.peakMemoryBytes == peakMemoryBytes &&
      other.accelerationBytes == accelerationBytes;

  @override
  int get hashCode =>
      Object.hash(id, displayName, bytes, quality, peakMemoryBytes, accelerationBytes);
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
/// Speech implements this; the whisper.cpp engine is batch-only. The
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

/// An engine that answers per-language readiness WITHOUT side effects: no
/// download started, no permission prompt raised, safe to call from any
/// surface at any time (a list screen probing sixty rows, a preflight before
/// onboarding has asked for anything). Distinct from [checkAvailability],
/// which may request speech authorization when it is undetermined.
abstract interface class LanguageReadinessEngine implements TranscriptionEngine {
  /// Whether [localeId] can transcribe on this device right now.
  Future<bool> localeReady({required String localeId});
}

/// An engine whose on-device model is downloaded and managed on the device. Apple
/// Speech implements this (its language assets) and so does the whisper.cpp
/// engine (its model file). An engine with no downloadable model does not implement it,
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
  /// Callers still promise not to run two installs for the SAME locale, and
  /// to listen to the returned stream immediately: a serializing
  /// implementation may release its turn only from the stream's lifecycle, so
  /// an unlistened stream can wedge every later install.
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

/// An engine that offers a choice of models, one of which serves every
/// language it supports (whisper's tiers). The choice is a preference the app
/// persists and hands back through [selectModel]; the engine only records it.
/// [ManagedModelEngine]'s per-language questions answer for the selected
/// model. An id outside [models] is an [ArgumentError] on every method that
/// takes one. Capability by type, no flag.
abstract interface class ModelChoiceEngine implements TranscriptionEngine {
  /// Every model the engine can run, in the order a picker lists them.
  List<ModelOption> get models;

  /// The model runs and installs use. Always one of [models]. A run takes
  /// the choice as it stands when it is asked for and keeps it, so a caller
  /// reading this just before asking knows the model that runs.
  String get selectedModelId;

  /// Records the choice. Nothing is downloaded or deleted, and a run already
  /// asked for keeps its model.
  Future<void> selectModel(String id);

  /// The ids whose files are present and whole. Preflight: never throws.
  Future<Set<String>> installedModels();

  /// Downloads one model, streaming progress and ending with a
  /// [ModelInstallProgress.done] event. Same rules as
  /// [ManagedModelEngine.installModel]: listen immediately, one install per id,
  /// overlapping ids serialized by the engine. A no-op stream when the file is
  /// already present.
  Stream<ModelInstallProgress> installModelById(String id);

  /// Deletes one model's file. Answers whether a file was deleted; refused
  /// (false) while a run, queued or in flight, holds the model, or a download
  /// for it (the model or its acceleration file) runs. The selection is left
  /// as is, so a removed selected model reads as not installed.
  Future<bool> removeModel(String id);
}

/// An engine whose batch pass needs its own time budget: a caller allows
/// [batchBudget] for a file of that length before treating the run as hung.
/// Engines without it get the caller's default.
abstract interface class PacedBatchEngine implements TranscriptionEngine {
  /// Under a model choice, answers for a run asked for now, on the model it
  /// would take.
  Duration batchBudget(Duration audio);
}

/// An engine holding memory it can give back while idle: a loaded model, a
/// worker. A caller that switches away calls [release]; a run in flight
/// fails as cancelled, and the next run loads again. Safe at any time.
abstract interface class ReleasableEngine implements TranscriptionEngine {
  Future<void> release();
}

/// An engine whose batch pass can say how far it is. [transcribeFileWithProgress]
/// is [TranscriptionEngine.transcribeFile] with a listener: fractions in
/// `[0, 1]`, in order, never after the future settles, none at all for a run
/// the engine cannot measure, and not necessarily reaching one: the future's
/// settling is the end, not a fraction. The plain [transcribeFile] is the
/// same run with no listener.
abstract interface class ProgressBatchEngine implements TranscriptionEngine {
  Future<Transcript> transcribeFileWithProgress(
    File audio, {
    required String localeId,
    required void Function(double fraction) onProgress,
    Duration? start,
    Duration? end,
  });
}

/// A [ModelChoiceEngine] whose models run faster with a second on-device
/// file each (whisper's Core ML encoder on the Neural Engine). The choice is
/// a preference the app persists and hands back through [setAccelerated].
/// Guarantees: [canAccelerate] false means the rest is inert (the platform
/// has no such path); with acceleration on, [ModelChoiceEngine.installModelById]
/// fetches the extra file too and a run uses it when present; off means no
/// run uses one: every extra file is deleted, a run in flight keeping its
/// own until it ends; [installAcceleration] fetches one model's extra file
/// under the install rules of [installModelById] and ends only once a run
/// can use it, or at once while the switch is off; [acceleratedModels]
/// never throws.
abstract interface class AcceleratedModelEngine implements ModelChoiceEngine {
  bool get canAccelerate;

  bool get accelerated;

  Future<void> setAccelerated(bool on);

  /// The ids whose extra file is present and whole.
  Future<Set<String>> acceleratedModels();

  Stream<ModelInstallProgress> installAcceleration(String id);
}
