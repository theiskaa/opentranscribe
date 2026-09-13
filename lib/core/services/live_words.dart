import 'package:opentranscribe/core/services/transcript_stitch.dart';

/// A take's live words across its language switches. A switch restarts the
/// live pass, whose words then carry only its own span, so the words of the
/// passes before are kept here, marked where their language changes from the
/// words before them, as a span-by-span pass marks its switches.
final class LiveWords {
  String _kept = '';
  String? _keptLocaleId;
  String? _firstLocaleId;
  String _running = '';

  /// The language the kept words were first spoken in; null before a pass
  /// that heard words has ended.
  String? get firstLocaleId => _firstLocaleId;

  /// The running pass's latest words, replacing its earlier ones.
  void update(String words) => _running = words;

  /// Every word so far, the running pass's heard in [localeId].
  String text(String localeId) {
    final before = _keptLocaleId;
    return appendText(
      _kept,
      _running,
      marker: before != null && languageDiffers(before, localeId),
      tag: localeId,
    );
  }

  /// The running pass, heard in [localeId], ends: its words are kept.
  void commit(String localeId) {
    if (_running.trim().isNotEmpty) {
      _kept = text(localeId);
      _keptLocaleId = localeId;
      _firstLocaleId ??= localeId;
    }
    _running = '';
  }

  void clear() {
    _kept = '';
    _keptLocaleId = null;
    _firstLocaleId = null;
    _running = '';
  }
}
