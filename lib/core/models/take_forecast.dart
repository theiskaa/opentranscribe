import 'package:flutter/foundation.dart';

/// What a just-recorded take is expected to read as, for a surface holding
/// its place while its pass runs: its length, how much of it was spoken, the
/// language it opened in, and about how many characters the words will be.
/// A guess by construction; nothing may treat [characters] as the text's.
@immutable
final class TakeForecast {
  const TakeForecast({
    required this.audio,
    required this.speech,
    required this.localeId,
    required this.characters,
  });

  final Duration audio;
  final Duration speech;
  final String localeId;
  final int characters;

  @override
  bool operator ==(Object other) =>
      other is TakeForecast &&
      other.audio == audio &&
      other.speech == speech &&
      other.localeId == localeId &&
      other.characters == characters;

  @override
  int get hashCode => Object.hash(audio, speech, localeId, characters);
}
