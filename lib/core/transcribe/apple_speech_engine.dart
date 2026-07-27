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

  /// The events channel, listened ONCE and fanned into [_liveHub]. Session
  /// lifecycle is driven by the startLive/stopLive method calls below, never by
  /// subscribing or cancelling this channel, so one take's teardown can never
  /// race the next take's setup (the bug where a new recording either inherited
  /// the old transcript or got no live text at all). Both live for the app's
  /// lifetime by design.
  // ignore: close_sinks
  StreamController<Map<String, dynamic>>? _liveHub;
  // ignore: cancel_subscriptions
  StreamSubscription<Object?>? _liveChannelSub;

  Stream<Map<String, dynamic>> get _liveEvents {
    // ignore: close_sinks
    final hub = _liveHub ??= StreamController<Map<String, dynamic>>.broadcast();
    _liveChannelSub ??= _events.receiveBroadcastStream().listen((raw) {
      if (raw is Map) hub.add(raw.cast<String, dynamic>());
    });
    return hub.stream;
  }

  /// A unique token per live session, sent with startLive and stamped on every
  /// event so each take's stream sees only its own.
  int _liveSessionSeq = 0;

  @override
  Stream<TranscriptEvent> transcribeLive({required String localeId}) {
    final session = ++_liveSessionSeq;
    final controller = StreamController<TranscriptEvent>();
    StreamSubscription<Map<String, dynamic>>? sub;

    Future<void> settle() async {
      await sub?.cancel();
      sub = null;
      if (!controller.isClosed) await controller.close();
    }

    controller.onListen = () {
      sub = _liveEvents.where((map) => map['session'] == session).listen((map) {
        if (map['type'] == 'error') {
          controller.addError(
            _mapError(map['code'] as String?, map['message'] as String?, payload: map),
          );
          unawaited(settle());
          return;
        }
        controller.add(
          TranscriptEvent(
            text: (map['text'] as String?) ?? '',
            isFinal: (map['isFinal'] as bool?) ?? false,
            segments: _segments(map['segments']),
          ),
        );
        if ((map['isFinal'] as bool?) ?? false) unawaited(settle());
      });
      _methods
          .invokeMethod<void>('startLive', {'session': session, 'localeId': localeId})
          .catchError((Object error) {
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
          });
    };
    controller.onCancel = () async {
      unawaited(_methods.invokeMethod<void>('stopLive', {'session': session}));
      await settle();
    };
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
