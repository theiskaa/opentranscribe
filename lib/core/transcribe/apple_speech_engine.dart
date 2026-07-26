import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'package:opentranscribe/core/transcribe/transcript.dart';
import 'package:opentranscribe/core/transcribe/transcript_event.dart';
import 'package:opentranscribe/core/transcribe/transcription_engine.dart';
import 'package:opentranscribe/core/transcribe/transcription_exception.dart';

// Channel identifiers. Must match SpeechEngine.swift.
const _controlChannel = 'opentranscribe/speech';
const _eventChannel = 'opentranscribe/speech/events';
const _modelChannel = 'opentranscribe/speech/model';

/// Apple on-device Speech, reached over platform channels, behind the
/// [StreamingTranscriptionEngine] and [ManagedModelEngine] contracts. Live results
/// stream over an EventChannel; batch (re-transcription, tests) goes over the
/// MethodChannel; model install streams over its own EventChannel. Nothing above
/// this file names Apple Speech. On-device only.
class AppleSpeechEngine implements StreamingTranscriptionEngine, ManagedModelEngine {
  AppleSpeechEngine({
    MethodChannel? methods,
    EventChannel? events,
    EventChannel? modelEvents,
    DateTime Function()? clock,
  }) : _methods = methods ?? const MethodChannel(_controlChannel),
       _events = events ?? const EventChannel(_eventChannel),
       _modelEvents = modelEvents ?? const EventChannel(_modelChannel),
       _clock = clock ?? DateTime.now;

  final MethodChannel _methods;
  final EventChannel _events;
  final EventChannel _modelEvents;
  final DateTime Function() _clock;

  @override
  String get id => 'apple.speech';

  @override
  bool get onDeviceOnly => true;

  @override
  Future<Availability> checkAvailability({required String localeId}) async {
    try {
      final result = await _methods.invokeMapMethod<String, dynamic>('checkAvailability', {
        'localeId': localeId,
      });
      return _availabilityFrom(result?['status'] as String?);
    } on PlatformException catch (e) {
      return Availability(AvailabilityStatus.onDeviceUnavailable, detail: e.message);
    } on MissingPluginException catch (e) {
      // A preflight probe must never throw; no plugin means no engine here.
      return Availability(AvailabilityStatus.onDeviceUnavailable, detail: e.message);
    }
  }

  @override
  Future<List<String>> supportedLocales() async {
    try {
      return await _methods.invokeListMethod<String>('supportedLocales') ?? const [];
    } on PlatformException {
      // A picker with no data beats a throw in a preflight.
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }

  @override
  Future<bool> isModelInstalled({required String localeId}) async {
    try {
      return await _methods.invokeMethod<bool>('isModelInstalled', {'localeId': localeId}) ?? false;
    } on PlatformException {
      // An unknown install state is treated as not-ready rather than surfaced.
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<List<String>> installedLocales() async {
    try {
      return await _methods.invokeListMethod<String>('installedLocales') ?? const [];
    } on PlatformException {
      // A preflight probe never throws; no answer reads as nothing installed.
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }

  @override
  Future<LocaleModelStatus> localeStatus({required String localeId}) async {
    try {
      final result = await _methods.invokeMapMethod<String, dynamic>('localeStatus', {
        'localeId': localeId,
      });
      return LocaleModelStatus(
        status: _assetStatusFrom(result?['status']) ?? ModelAssetStatus.supported,
        reserved: (result?['reserved'] as bool?) ?? false,
        resolvedTag: (result?['resolvedTag'] as String?) ?? localeId,
      );
    } on PlatformException {
      // Unknown state reads as downloadable-but-not-ready: it neither promises
      // a model that may be absent nor writes a language off as unsupported.
      return LocaleModelStatus(
        status: ModelAssetStatus.supported,
        reserved: false,
        resolvedTag: localeId,
      );
    } on MissingPluginException {
      return LocaleModelStatus(
        status: ModelAssetStatus.supported,
        reserved: false,
        resolvedTag: localeId,
      );
    }
  }

  @override
  Future<bool> removeLanguage({required String localeId}) async {
    try {
      return await _methods.invokeMethod<bool>('removeLanguage', {'localeId': localeId}) ?? false;
    } on PlatformException {
      // Nothing released is the honest answer when the channel cannot say.
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<ReservationInfo> reservationInfo() async {
    try {
      final result = await _methods.invokeMapMethod<String, dynamic>('reservationInfo');
      return ReservationInfo(
        max: (result?['max'] as num?)?.toInt() ?? 0,
        reservedTags: _stringList(result?['reserved']),
      );
    } on PlatformException {
      // max 0 is the contract's "could not answer": the UI renders no cap.
      return const ReservationInfo(max: 0, reservedTags: []);
    } on MissingPluginException {
      return const ReservationInfo(max: 0, reservedTags: []);
    }
  }

  /// Completes when the most recent install stream's channel teardown finished,
  /// so overlapping installs serialize instead of decapitating each other (the
  /// same EventChannel hazard [transcribeLive] guards with its teardown, plus
  /// one more: the native install handler is single-flight, so a second listen
  /// would CANCEL the first download and leave its Dart stream waiting forever).
  /// Latched at call time, released from onListen/onCancel: a returned stream
  /// nobody listens to would hold successors, so every call site listens
  /// immediately.
  Future<void>? _installTeardown;

  @override
  Stream<ModelInstallProgress> installModel({required String localeId}) {
    final prior = _installTeardown;
    final teardown = Completer<void>();
    _installTeardown = teardown.future;

    // A manual controller, NOT async*: a generator suspended in `await for` on
    // a channel that will never speak again cannot be unwound by a consumer
    // cancel (cancellation lands at yields), which would hang the cancel and
    // deadlock the teardown chain above. Here onCancel tears the channel
    // subscription down directly, whatever state the install is in.
    // Cancelled in settle(), which every exit path runs; the lint cannot see
    // through the closures.
    // ignore: cancel_subscriptions
    StreamSubscription<Object?>? channelSub;
    late final StreamController<ModelInstallProgress> controller;

    Future<void> settle() async {
      final sub = channelSub;
      channelSub = null;
      // Channel teardown FIRST, then completion: consumers observing the end
      // of this stream may immediately start the next install.
      await sub?.cancel();
      if (!teardown.isCompleted) teardown.complete();
      if (!controller.isClosed) await controller.close();
    }

    controller = StreamController<ModelInstallProgress>(
      onListen: () async {
        if (prior != null) await prior;
        // The consumer may have given up while queued behind a prior install.
        if (!controller.hasListener || controller.isClosed) return;
        channelSub = _modelEvents
            .receiveBroadcastStream({'localeId': localeId})
            .listen(
              (raw) {
                if (raw is! Map) return;
                final map = raw.cast<String, dynamic>();
                if (map['type'] == 'error') {
                  controller.addError(
                    _mapError(map['code'] as String?, map['message'] as String?, payload: map),
                  );
                  unawaited(settle());
                  return;
                }
                final progress = ModelInstallProgress(
                  fraction: (map['fraction'] as num?)?.toDouble() ?? 0,
                  done: (map['done'] as bool?) ?? false,
                );
                controller.add(progress);
                // Install is settled; stop listening so the stream completes.
                if (progress.done) unawaited(settle());
              },
              onError: (Object error) {
                controller.addError(switch (error) {
                  PlatformException(:final code, :final message, :final details) => _mapError(
                    code,
                    message,
                    details: details,
                  ),
                  MissingPluginException(:final message) => ModelInstallFailed(message),
                  _ => error,
                });
                unawaited(settle());
              },
              onDone: () => unawaited(settle()),
            );
      },
      onCancel: settle,
    );
    return controller.stream;
  }

  @override
  Future<Transcript> transcribeFile(
    File audio, {
    required String localeId,
    Duration? start,
    Duration? end,
  }) async {
    try {
      final result = await _methods.invokeMapMethod<String, dynamic>('transcribeFile', {
        'path': audio.path,
        'localeId': localeId,
        if (start != null) 'startMs': start.inMilliseconds,
        if (end != null) 'endMs': end.inMilliseconds,
      });
      if (result == null) {
        // A null reply is a protocol breach, not the valid empty-transcript result
        // (silence comes back as an empty text field, never as no map).
        throw const TranscriptionFailed('empty native reply');
      }
      return Transcript(
        fullText: (result['text'] as String?) ?? '',
        segments: _segments(result['segments']),
        localeId: localeId,
        engineId: id,
        createdAt: _clock(),
      );
    } on PlatformException catch (e) {
      throw _mapError(e.code, e.message, details: e.details);
    } on MissingPluginException catch (e) {
      throw TranscriptionFailed(e.message);
    }
  }

  /// Completes when the most recent live stream's channel teardown finished, so
  /// the next session's listen cannot be decapitated by it (see [transcribeLive]).
  /// Latched at call time, released from onListen/onCancel: a returned stream
  /// nobody listens to would hold successors, so every call site listens
  /// immediately.
  Future<void>? _liveTeardown;

  @override
  Stream<TranscriptEvent> transcribeLive({required String localeId}) {
    // EventChannel cancels are per-call and ownerless: a previous live stream's
    // cancel, arriving AFTER a new listen on the same channel name, would null the
    // new handler and stop the new native session. Serialize: wait for the prior
    // stream's full teardown before issuing this listen. (The recorder avoids this
    // with one shared stream; here the listen arguments differ per call.)
    final prior = _liveTeardown;
    final teardown = Completer<void>();
    _liveTeardown = teardown.future;

    // A manual controller, NOT async*, for the same reason as [installModel]:
    // a mid-session cancel (a language switch) lands while the generator is
    // suspended on a channel that will never speak again, and generator
    // cancellation only takes effect at a yield - the cancel would hang, the
    // native session would never stop, and the next session would never start.
    // Cancelled in settle(), which every exit path runs; the lint cannot see
    // through the closures.
    // ignore: cancel_subscriptions
    StreamSubscription<Object?>? channelSub;
    late final StreamController<TranscriptEvent> controller;

    Future<void> settle() async {
      final sub = channelSub;
      channelSub = null;
      // Channel teardown FIRST, then completion: the successor session's
      // listen queues behind this teardown.
      await sub?.cancel();
      if (!teardown.isCompleted) teardown.complete();
      if (!controller.isClosed) await controller.close();
    }

    controller = StreamController<TranscriptEvent>(
      onListen: () async {
        if (prior != null) await prior;
        // The consumer may have given up while queued behind the prior session.
        if (!controller.hasListener || controller.isClosed) return;
        // Passing localeId as the listen argument lets the native side build the
        // recognizer for the right locale. Recognition is started in native
        // onListen (and stopped in onCancel), so partials never arrive before
        // the sink exists.
        channelSub = _events
            .receiveBroadcastStream({'localeId': localeId})
            .listen(
              (raw) {
                if (raw is! Map) return;
                final map = raw.cast<String, dynamic>();
                if (map['type'] == 'error') {
                  controller.addError(
                    _mapError(map['code'] as String?, map['message'] as String?, payload: map),
                  );
                  unawaited(settle());
                  return;
                }
                final event = TranscriptEvent(
                  text: (map['text'] as String?) ?? '',
                  isFinal: (map['isFinal'] as bool?) ?? false,
                  segments: _segments(map['segments']),
                );
                controller.add(event);
                // Recognition is settled; stop listening so the stream completes.
                if (event.isFinal) unawaited(settle());
              },
              onError: (Object error) {
                // A raw channel error becomes a typed failure, like the batch path.
                controller.addError(switch (error) {
                  PlatformException(:final code, :final message, :final details) => _mapError(
                    code,
                    message,
                    details: details,
                  ),
                  MissingPluginException(:final message) => TranscriptionFailed(message),
                  _ => error,
                });
                unawaited(settle());
              },
              onDone: () => unawaited(settle()),
            );
      },
      onCancel: settle,
    );
    return controller.stream;
  }

  Availability _availabilityFrom(String? status) => switch (status) {
    'available' => const Availability.available(),
    'permission_denied' => const Availability(AvailabilityStatus.permissionDenied),
    _ => const Availability(AvailabilityStatus.onDeviceUnavailable),
  };

  List<TranscriptSegment> _segments(Object? raw) {
    if (raw is! List) return const [];
    final segments = <TranscriptSegment>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final map = entry.cast<String, dynamic>();
      final startMs = map['startMs'] as num?;
      final endMs = map['endMs'] as num?;
      // An untimed segment is dropped, matching the native side, rather than
      // fabricated as a zero-length span at the start of the audio.
      if (startMs == null || endMs == null) continue;
      segments.add(
        TranscriptSegment(
          text: (map['text'] as String?) ?? '',
          start: Duration(milliseconds: startMs.toInt()),
          end: Duration(milliseconds: endMs.toInt()),
          confidence: (map['confidence'] as num?)?.toDouble(),
        ),
      );
    }
    return segments;
  }

  // The conditions the app reasons about get typed exceptions; the remaining native
  // codes (file_missing, transcribe_error, bad_args) are all just failures to the
  // app, so they collapse to TranscriptionFailed on purpose. Structured extras ride
  // in [payload] (stream error events) or [details] (method-channel errors): the
  // asset status behind an install failure, the reserved tags behind a full cap.
  TranscriptionException _mapError(
    String? code,
    String? message, {
    Map<String, dynamic>? payload,
    Object? details,
  }) {
    final extras = payload ?? (details is Map ? details.cast<String, dynamic>() : null);
    return switch (code) {
      'permission_denied' => PermissionDenied(message),
      'on_device_unavailable' => OnDeviceUnavailable(message),
      'model_install_failed' => ModelInstallFailed(message, _assetStatusFrom(extras?['status'])),
      'reservation_cap' => ReservationCapReached(_stringList(extras?['reservedTags']), message),
      _ => TranscriptionFailed(message),
    };
  }
}

/// The channel's status strings, one spelling with SpeechEngine.swift.
ModelAssetStatus? _assetStatusFrom(Object? raw) => switch (raw) {
  'unsupported' => ModelAssetStatus.unsupported,
  'supported' => ModelAssetStatus.supported,
  'downloading' => ModelAssetStatus.downloading,
  'installed' => ModelAssetStatus.installed,
  _ => null,
};

List<String> _stringList(Object? raw) =>
    raw is List ? raw.whereType<String>().toList(growable: false) : const [];
