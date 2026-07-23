import 'dart:io';

import 'package:flutter/services.dart';

import 'package:opentranscribe/core/transcribe/transcript.dart';
import 'package:opentranscribe/core/transcribe/transcript_event.dart';
import 'package:opentranscribe/core/transcribe/transcription_engine.dart';
import 'package:opentranscribe/core/transcribe/transcription_exception.dart';

// Channel identifiers. Must match SpeechEngine.swift.
const _controlChannel = 'opentranscribe/speech';
const _eventChannel = 'opentranscribe/speech/events';

/// Apple on-device Speech, reached over platform channels, behind the
/// [StreamingTranscriptionEngine] contract. Live results stream over an
/// EventChannel; batch (re-transcription, tests) goes over the MethodChannel.
/// Nothing above this file names Apple Speech. On-device only.
class AppleSpeechEngine implements StreamingTranscriptionEngine {
  AppleSpeechEngine({MethodChannel? methods, EventChannel? events, DateTime Function()? clock})
    : _methods = methods ?? const MethodChannel(_controlChannel),
      _events = events ?? const EventChannel(_eventChannel),
      _clock = clock ?? DateTime.now;

  final MethodChannel _methods;
  final EventChannel _events;
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
    }
  }

  @override
  Future<Transcript> transcribeFile(File audio, {required String localeId}) async {
    try {
      final result = await _methods.invokeMapMethod<String, dynamic>('transcribeFile', {
        'path': audio.path,
        'localeId': localeId,
      });
      return Transcript(
        fullText: (result?['text'] as String?) ?? '',
        segments: _segments(result?['segments']),
        localeId: localeId,
        engineId: id,
        createdAt: _clock().toUtc(),
      );
    } on PlatformException catch (e) {
      throw _mapError(e.code, e.message);
    }
  }

  @override
  Stream<TranscriptEvent> transcribeLive({required String localeId}) async* {
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
      segments.add(
        TranscriptSegment(
          text: (map['text'] as String?) ?? '',
          start: Duration(milliseconds: (map['startMs'] as num?)?.toInt() ?? 0),
          end: Duration(milliseconds: (map['endMs'] as num?)?.toInt() ?? 0),
          confidence: (map['confidence'] as num?)?.toDouble(),
        ),
      );
    }
    return segments;
  }

  // The two conditions the app reasons about get typed exceptions; the remaining
  // native codes (file_missing, transcribe_error, bad_args) are all just failures
  // to the app, so they collapse to TranscriptionFailed on purpose.
  TranscriptionException _mapError(String? code, String? message) => switch (code) {
    'permission_denied' => PermissionDenied(message),
    'on_device_unavailable' => OnDeviceUnavailable(message),
    _ => TranscriptionFailed(message),
  };
}
