import 'dart:ui' as ui;

import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/services/transcription_service.dart';
import 'package:opentranscribe/core/utils/language_tags.dart';

/// Persists and applies the transcription language. Deliberately independent of
/// the UI language (AppLanguage): what you speak is not what the buttons say.
/// Defaults to the DEVICE locale, so a German phone transcribes German out of
/// the box with no setting touched. The device tag is RESOLVED against the
/// engine's supported list in [apply]: a phone pairing a language with a region
/// no model ships for (Turkish in Georgia reports tr-GE) must default to the
/// supported variant of that language, never to a tag the engine will refuse.
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

  /// The device tag resolved to a language the engine can run, set by [apply].
  String? _resolvedDeviceTag;
  bool _deviceLanguageUnsupported = false;

  /// The transcription language as a BCP-47 tag: the stored choice, or the
  /// resolved device locale when none was ever set. A STORED tag the engine
  /// does not support is kept as chosen; availability surfaces the gap (never
  /// a silent fallback to another language). Falls back to the device tag when
  /// the stored value cannot be decrypted (key change, corruption).
  String get localeId {
    try {
      return _storage.readString(_key) ?? deviceLocaleId;
    } catch (_) {
      return deviceLocaleId;
    }
  }

  /// The device locale's tag resolved to a supported language: what [localeId]
  /// falls back to when nothing was chosen, and what the default returns to
  /// when its language is removed. Raw before [apply] has asked the engine.
  String get deviceLocaleId => _resolvedDeviceTag ?? _deviceTag();

  /// True when the device language has no supported variant at all, so the
  /// derived default fell back (see [apply]).
  bool get deviceLanguageUnsupported => _deviceLanguageUnsupported;

  /// Resolves the device default against the engine's supported list, then
  /// pushes the current language to the service. The chain: a supported
  /// variant of the device language, else English, else the engine's first
  /// language, else the raw tag (an empty answer resolves nothing, so nothing
  /// wrong is cached). A stored tag persisted before resolution existed
  /// migrates to its language's supported spelling (tr-GE to tr-TR); a stored
  /// LANGUAGE the engine cannot run at all is kept as chosen. Called once at
  /// startup; the change lands on the next recording (a live session keeps
  /// its locale).
  Future<void> apply() async {
    final supported = await _service.supportedLocales();
    if (supported.isNotEmpty) {
      final device = resolveSupportedTag(_deviceTag(), supported);
      _deviceLanguageUnsupported = device == null;
      _resolvedDeviceTag = device ?? resolveSupportedTag('en-US', supported) ?? supported.first;
      await _migrateStored(supported);
    }
    _service.localeId = localeId;
  }

  /// Rewrites a stored tag from before device tags were resolved: same
  /// language, supported spelling. Never crosses languages.
  Future<void> _migrateStored(List<String> supported) async {
    String? stored;
    try {
      stored = _storage.readString(_key);
    } catch (_) {
      return;
    }
    if (stored == null) return;
    final resolved = resolveSupportedTag(stored, supported);
    if (resolved != null && resolved != stored) await _storage.write(_key, resolved);
  }

  /// Sets and applies the language. Persisted so it survives relaunches. Throws
  /// when persisting fails, and applies nothing then: the state stays consistent
  /// on the previous language, and the caller surfaces the failure.
  Future<void> setLocaleId(String tag) async {
    await _storage.write(_key, tag);
    _service.localeId = tag;
  }
}
