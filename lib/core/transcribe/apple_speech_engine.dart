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
  Stream<ModelInstallProgress> installModel({required String localeId}) async* {
    final stream = _modelEvents.receiveBroadcastStream({'localeId': localeId});
    try {
      await for (final raw in stream) {
        if (raw is! Map) continue;
        final map = raw.cast<String, dynamic>();
        if (map['type'] == 'error') {
          throw _mapError(map['code'] as String?, map['message'] as String?);
        }
        final progress = ModelInstallProgress(
          fraction: (map['fraction'] as num?)?.toDouble() ?? 0,
          done: (map['done'] as bool?) ?? false,
        );
        yield progress;
        // Install is settled; stop listening so the stream completes.
        if (progress.done) return;
      }
    } on TranscriptionException {
      rethrow;
    } on PlatformException catch (e) {
      throw _mapError(e.code, e.message);
    } on MissingPluginException catch (e) {
      throw ModelInstallFailed(e.message);
    }
  }

  @override
  Future<Transcript> transcribeFile(File audio, {required String localeId}) async {
    try {
      final result = await _methods.invokeMapMethod<String, dynamic>('transcribeFile', {
        'path': audio.path,
        'localeId': localeId,
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
      throw _mapError(e.code, e.message);
    } on MissingPluginException catch (e) {
      throw TranscriptionFailed(e.message);
    }
  }

  /// Completes when the most recent live stream's channel teardown finished, so
  /// the next session's listen cannot be decapitated by it (see [transcribeLive]).
  Future<void>? _liveTeardown;

  @override
  Stream<TranscriptEvent> transcribeLive({required String localeId}) async* {
    // EventChannel cancels are per-call and ownerless: a previous live stream's
    // cancel, arriving AFTER a new listen on the same channel name, would null the
    // new handler and stop the new native session. Serialize: wait for the prior
    // stream's full teardown before issuing this listen. (The recorder avoids this
    // with one shared stream; here the listen arguments differ per call.)
    final prior = _liveTeardown;
    final teardown = Completer<void>();
    _liveTeardown = teardown.future;
    try {
      if (prior != null) await prior;
      // Passing localeId as the listen argument lets the native side build the
      // recognizer for the right locale. Recognition is started in native onListen
      // (and stopped in onCancel), so partials never arrive before the sink exists.
      final stream = _events.receiveBroadcastStream({'localeId': localeId});
      try {
        await for (final raw in stream) {
          if (raw is! Map) continue;
          final map = raw.cast<String, dynamic>();
          if (map['type'] == 'error') {
            throw _mapError(map['code'] as String?, map['message'] as String?);
          }
          final event = TranscriptEvent(
            text: (map['text'] as String?) ?? '',
            isFinal: (map['isFinal'] as bool?) ?? false,
            segments: _segments(map['segments']),
          );
          yield event;
          // Recognition is settled; stop listening so the stream completes.
          if (event.isFinal) return;
        }
      } on TranscriptionException {
        rethrow;
      } on PlatformException catch (e) {
        // A raw channel error becomes a typed failure, like the batch path.
        throw _mapError(e.code, e.message);
      } on MissingPluginException catch (e) {
        throw TranscriptionFailed(e.message);
      }
    } finally {
      // Runs after the consumer's cancel completes, which includes the channel's
      // own async onCancel (handler nulled + native 'cancel' delivered).
      teardown.complete();
    }
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
  // app, so they collapse to TranscriptionFailed on purpose.
  TranscriptionException _mapError(String? code, String? message) => switch (code) {
    'permission_denied' => PermissionDenied(message),
    'on_device_unavailable' => OnDeviceUnavailable(message),
    'model_install_failed' => ModelInstallFailed(message),
    _ => TranscriptionFailed(message),
  };
}
