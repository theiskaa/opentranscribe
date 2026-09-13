import 'package:flutter/foundation.dart';

/// What a just-recorded take is expected to read as, for a surface holding
/// its place while its pass runs: its length, how much of it was spoken, the
/// language it opened in, about how many characters the words will be, and
/// the words a live pass already heard. [characters] is a guess by
/// construction; nothing may treat it as the text's.
@immutable
final class TakeForecast {
  const TakeForecast({
    required this.audio,
    required this.speech,
    required this.localeId,
    required this.characters,
    this.heard = '',
  });

  final Duration audio;
  final Duration speech;
  final String localeId;
  final int characters;

  /// What the take's live pass heard, empty under an engine without one: a
  /// surface shows these words while the pass runs, and ink only without.
  final String heard;

  @override
  bool operator ==(Object other) =>
      other is TakeForecast &&
      other.audio == audio &&
      other.speech == speech &&
      other.localeId == localeId &&
      other.characters == characters &&
      other.heard == heard;

  @override
  int get hashCode => Object.hash(audio, speech, localeId, characters, heard);
}
