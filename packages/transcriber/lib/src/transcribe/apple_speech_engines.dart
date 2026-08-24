import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

import 'package:transcriber/src/transcribe/transcript.dart';
import 'package:transcriber/src/transcribe/transcript_event.dart';
import 'package:transcriber/src/transcribe/transcription_engine.dart';
import 'package:transcriber/src/transcribe/transcription_exception.dart';

// Channel identifiers. Must match SpeechEngine.swift.
const _controlChannel = 'transcriber/speech';
const _eventChannel = 'transcriber/speech/events';
const _modelChannel = 'transcriber/speech/model';

// Engine argument values. Must match EngineRoute in SpeechEngine.swift.
const _analyzerRoute = 'analyzer';
const _classicRoute = 'classic';

/// The live half of the speech channel, shared by every engine over it. The
/// events channel is listened ONCE, here, and fanned out by session token: a
/// Flutter EventChannel admits one Dart-side listener per name, so a second
/// engine subscribing on its own would displace the first and leave its live
/// streams permanently silent. The session sequence lives here too, because
/// the native side tracks one session for the whole channel, whichever engine
/// drives it; per-engine counters would mint colliding tokens. Session
/// lifecycle is driven by the startLive/stopLive method calls, never by
/// subscribing or cancelling this channel, and the subscription lives for the
/// app's lifetime by design. Engines default to one process-wide instance;
/// tests inject a fresh one per case for isolation.
class SpeechLiveTransport {
  SpeechLiveTransport({EventChannel? events})
    : _events = events ?? const EventChannel(_eventChannel);

  final EventChannel _events;

  // ignore: close_sinks
  StreamController<Map<String, dynamic>>? _hub;
  // ignore: cancel_subscriptions
  StreamSubscription<Object?>? _channelSub;
  int _sessionSeq = 0;

  /// A unique token per live session across every engine on this channel, sent
  /// with startLive and stamped on every event so each take's stream sees only
  /// its own.
  int nextSession() => ++_sessionSeq;

  Stream<Map<String, dynamic>> get events {
    // ignore: close_sinks
    final hub = _hub ??= StreamController<Map<String, dynamic>>.broadcast();
    _channelSub ??= _events.receiveBroadcastStream().listen((raw) {
      if (raw is Map) hub.add(raw.cast<String, dynamic>());
    });
    return hub.stream;
  }
}

/// Shared plumbing for the two Apple engines behind the transcriber/speech
/// channels: every engine-answering call stamps its engine argument so the
/// native side routes explicitly, and live events fan out of the one shared
/// [SpeechLiveTransport]. The public surface is [AppleSpeechEngine] and
/// [AppleDictationEngine]. On-device only.
abstract class _AppleChannelEngine implements StreamingTranscriptionEngine, CancellableBatchEngine {
  _AppleChannelEngine(
    this._route, {
    MethodChannel? methods,
    SpeechLiveTransport? live,
    DateTime Function()? clock,
  }) : _methods = methods ?? const MethodChannel(_controlChannel),
       _live = live ?? _sharedLive,
       _clock = clock ?? DateTime.now;

  // One transport per process by default: see [SpeechLiveTransport] for why
  // engines must not each carry their own.
  static final SpeechLiveTransport _sharedLive = SpeechLiveTransport();

  final String _route;
  final MethodChannel _methods;
  final SpeechLiveTransport _live;
  final DateTime Function() _clock;

  @override
  bool get onDeviceOnly => true;

  @override
  Future<Availability> checkAvailability({required String localeId}) async {
    try {
      final result = await _methods.invokeMapMethod<String, dynamic>('checkAvailability', {
        'localeId': localeId,
        'engine': _route,
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
      return await _methods.invokeListMethod<String>('supportedLocales', {'engine': _route}) ??
          const [];
    } on PlatformException {
      // A picker with no data beats a throw in a preflight.
      return const [];
    } on MissingPluginException {
      return const [];
    }
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
        'engine': _route,
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

  @override
  Future<void> cancelBatches() async {
    try {
      // No engine argument: cancellation abandons every in-flight batch on
      // both engines, matching the native handler.
      await _methods.invokeMethod<void>('cancelBatches');
    } on PlatformException {
      // Cancellation is best effort; a failed cancel changes nothing for the
      // caller, who has already given up on the batch.
    } on MissingPluginException {
      // Same: tests without a native side must not throw here.
    }
  }

  @override
  Stream<TranscriptEvent> transcribeLive({required String localeId}) {
    final session = _live.nextSession();
    final controller = StreamController<TranscriptEvent>();
    StreamSubscription<Map<String, dynamic>>? sub;

    Future<void> settle() async {
      await sub?.cancel();
      sub = null;
      if (!controller.isClosed) await controller.close();
    }

    controller.onListen = () {
      sub = _live.events.where((map) => map['session'] == session).listen((map) {
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
          .invokeMethod<void>('startLive', {
            'session': session,
            'localeId': localeId,
            'engine': _route,
          })
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
      final confidence = (map['confidence'] as num?)?.toDouble();
      segments.add(
        TranscriptSegment(
          text: (map['text'] as String?) ?? '',
          start: Duration(milliseconds: startMs.toInt()),
          end: Duration(milliseconds: endMs.toInt()),
          // Drop a non-finite confidence (some iOS builds report NaN for a
          // zero-confidence segment): it survives the channel but throws in
          // jsonEncode when the entry is saved, losing the whole transcript.
          confidence: (confidence != null && confidence.isFinite) ? confidence : null,
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

/// The iOS 26 SpeechAnalyzer engine, with its app-managed downloadable models.
/// Whether this device can run it at all is [analyzerAvailable]'s answer.
class AppleSpeechEngine extends _AppleChannelEngine implements ManagedModelEngine {
  AppleSpeechEngine({super.methods, super.live, EventChannel? modelEvents, super.clock})
    : _modelEvents = modelEvents ?? const EventChannel(_modelChannel),
      super(_analyzerRoute);

  final EventChannel _modelEvents;

  @override
  String get id => 'apple.speech';

  /// Whether the SpeechAnalyzer stack can run on this device: iOS 26 on
  /// hardware whose supported-locales answer is non-empty (the simulator
  /// always answers yes). Resolved natively once per process (with a deadline
  /// against a wedged catalog query), so the answer cannot flip within a
  /// session.
  Future<bool> analyzerAvailable() async {
    try {
      return await _methods.invokeMethod<bool>('analyzerAvailable') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<bool> isModelInstalled({required String localeId}) async {
    try {
      return await _methods.invokeMethod<bool>('isModelInstalled', {
            'localeId': localeId,
            'engine': _route,
          }) ??
          false;
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
      return await _methods.invokeListMethod<String>('installedLocales', {'engine': _route}) ??
          const [];
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
        'engine': _route,
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
      return await _methods.invokeMethod<bool>('removeLanguage', {
            'localeId': localeId,
            'engine': _route,
          }) ??
          false;
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
      final result = await _methods.invokeMapMethod<String, dynamic>('reservationInfo', {
        'engine': _route,
      });
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
            .receiveBroadcastStream({'localeId': localeId, 'engine': _route})
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
}

/// The classic SFSpeechRecognizer engine, the one behind iOS dictation. It
/// ships with the OS, so it runs on every supported iOS version and on
/// hardware the analyzer cannot serve. No app-managed models, deliberately NOT
/// a [ManagedModelEngine]: its models are the system dictation assets, managed
/// in iOS Settings.
class AppleDictationEngine extends _AppleChannelEngine implements LanguageReadinessEngine {
  AppleDictationEngine({super.methods, super.live, super.clock}) : super(_classicRoute);

  @override
  String get id => 'apple.dictation';

  @override
  Future<bool> localeReady({required String localeId}) async {
    try {
      // The classic localeStatus arm answers from the recognizer alone and
      // never requests authorization, which is this method's whole guarantee.
      final result = await _methods.invokeMapMethod<String, dynamic>('localeStatus', {
        'localeId': localeId,
        'engine': _route,
      });
      return result?['status'] == 'installed';
    } on PlatformException {
      // Not-ready is the honest fold when the channel cannot say.
      return false;
    } on MissingPluginException {
      return false;
    }
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
