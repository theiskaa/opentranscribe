import 'dart:async';

import 'package:flutter/services.dart';

import 'package:opentranscribe/core/reflect/reflection_engine.dart';
import 'package:opentranscribe/core/reflect/reflection_exception.dart';
import 'package:opentranscribe/core/reflect/reflection_options.dart';

// Channel identifier. Must match ReflectionEngine.swift.
const _controlChannel = 'opentranscribe/reflect';

// The native error code that means "could not run" (transient). Must match the
// ReflectErrorCode in ReflectionEngine.swift.
const _unavailableCode = 'unavailable';

/// Apple Foundation Models behind the [ReflectionEngine] contract, reached over
/// a MethodChannel. On-device only: it uses `SystemLanguageModel.default`, the
/// local model, never Private Cloud Compute or any server. Nothing above this
/// file names Foundation Models.
///
/// One-shot, so no EventChannel: a reflection is a single request/response, not
/// a stream. If streamed reading is ever wanted it is an additive interface,
/// exactly like `StreamingTranscriptionEngine`.
class FoundationModelsEngine implements ReflectionEngine {
  FoundationModelsEngine({MethodChannel? methods})
    : _methods = methods ?? const MethodChannel(_controlChannel);

  final MethodChannel _methods;

  @override
  String get id => 'foundation.models';

  @override
  bool get onDeviceOnly => true;

  @override
  Future<ReflectionAvailability> availability() async {
    try {
      final result = await _methods.invokeMapMethod<String, dynamic>('availability');
      return ReflectionAvailability(_statusFrom(result?['status'] as String?));
    } on PlatformException catch (e) {
      // A preflight probe never throws; an unreadable state reads as absent.
      return ReflectionAvailability(ReflectionAvailabilityStatus.unsupported, detail: e.message);
    } on MissingPluginException {
      return const ReflectionAvailability.unsupported();
    }
  }

  @override
  Future<String?> reflect({
    required List<ReflectionEntryInput> entries,
    required ReflectionStyle style,
    required String localeId,
  }) async {
    try {
      final result = await _methods.invokeMapMethod<String, dynamic>('reflect', {
        'entries': [for (final e in entries) e.toWire()],
        'style': style.toWire(),
        'localeId': localeId,
      });
      final text = (result?['text'] as String?)?.trim();
      // Empty output is silence, the default and valid outcome, not a failure.
      return (text == null || text.isEmpty) ? null : text;
    } on PlatformException catch (e) {
      // Only the native "could not run" reaches here; a guardrail refusal comes
      // back as empty text (silence) above, never as an error.
      throw ReflectionUnavailable(
        e.code == _unavailableCode ? e.message : '${e.code}: ${e.message}',
      );
    } on MissingPluginException catch (e) {
      // No plugin means the engine is not really here; treat as could-not-run so
      // the caller retries rather than persisting a false silence.
      throw ReflectionUnavailable(e.message);
    }
  }

  ReflectionAvailabilityStatus _statusFrom(String? status) => switch (status) {
    'available' => ReflectionAvailabilityStatus.available,
    'not_enabled' => ReflectionAvailabilityStatus.notEnabled,
    'model_not_ready' => ReflectionAvailabilityStatus.modelNotReady,
    'device_not_eligible' => ReflectionAvailabilityStatus.deviceNotEligible,
    _ => ReflectionAvailabilityStatus.unsupported,
  };
}
