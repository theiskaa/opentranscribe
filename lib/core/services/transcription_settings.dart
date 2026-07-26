import 'dart:ui' as ui;

import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/services/transcription_service.dart';

/// Persists and applies the transcription language. Deliberately independent of
/// the UI language (AppLanguage): what you speak is not what the buttons say.
/// Defaults to the DEVICE locale, so a German phone transcribes German out of
/// the box with no setting touched. This is the mechanism only; the language
/// picker is a later UI (fed by TranscriptionService.supportedLocales).
class TranscriptionSettings {
  TranscriptionSettings({
    required this._storage,
    required this._service,
    String Function()? deviceTag,
  }) : _deviceTag = deviceTag ?? _platformTag;

  final LocalService _storage;
  final TranscriptionService _service;

  /// Injectable for tests; the default reads the device locale as BCP-47.
  final String Function() _deviceTag;

  static String _platformTag() => ui.PlatformDispatcher.instance.locale.toLanguageTag();

  static const _key = 'transcribe.localeId';

  /// The transcription language as a BCP-47 tag: the stored choice, or the
  /// device locale when none was ever set. A stored tag the engine does not
  /// support is kept as chosen; availability surfaces the gap (never a silent
  /// fallback to another language). Falls back to the device tag when the
  /// stored value cannot be decrypted (key change, corruption).
  String get localeId {
    try {
      return _storage.readString(_key) ?? _deviceTag();
    } catch (_) {
      return _deviceTag();
    }
  }

  /// The device locale's tag: what [localeId] falls back to when nothing was
  /// chosen, and what the default returns to when its language is removed.
  String get deviceLocaleId => _deviceTag();

  /// Pushes the current language to the service. Called once at startup; the
  /// change lands on the next recording (a live session keeps its locale).
  void apply() {
    _service.localeId = localeId;
  }

  /// Sets and applies the language. Persisted so it survives relaunches. Throws
  /// when persisting fails, and applies nothing then: the state stays consistent
  /// on the previous language, and the caller surfaces the failure.
  Future<void> setLocaleId(String tag) async {
    await _storage.write(_key, tag);
    _service.localeId = tag;
  }
}
