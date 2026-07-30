/// The three knobs a user tunes for weekly reflections. They parameterize the
/// on-device prompt and nothing else: changing one never rewrites a reflection
/// already produced. Kept next to the engine so the Dart wrapper and the native
/// plugin agree on one spelling of each value; the `wire` string is that
/// cross-boundary contract, like SpeechEngine's error codes.
library;

/// How a reflection reads. [literary] is the default the other defaults are
/// tuned to.
enum ReflectionVoice {
  literary('literary'),
  observational('observational'),
  sparse('sparse');

  const ReflectionVoice(this.wire);

  final String wire;

  static const fallback = ReflectionVoice.literary;

  /// The voice for a stored [wire] value, or null when unrecognized (a record
  /// from a future build); callers fall back rather than throw.
  static ReflectionVoice? fromWire(String? wire) => _fromWire(values, (v) => v.wire, wire);
}

/// How long a reflection may run. Silence is always allowed regardless.
enum ReflectionLength {
  oneLine('one_line'),
  sentences('sentences'),
  paragraph('paragraph');

  const ReflectionLength(this.wire);

  final String wire;

  /// Tuned to [ReflectionVoice.literary].
  static const fallback = ReflectionLength.sentences;

  static ReflectionLength? fromWire(String? wire) => _fromWire(values, (v) => v.wire, wire);
}

/// Whether a reflection may name the specifics it heard (people, projects,
/// places), or stays with themes.
enum ReflectionSpecificity {
  nameFreely('name_freely'),
  abstractThemes('abstract'),
  letWeekDecide('let_week_decide');

  const ReflectionSpecificity(this.wire);

  final String wire;

  /// Tuned to [ReflectionVoice.literary].
  static const fallback = ReflectionSpecificity.nameFreely;

  static ReflectionSpecificity? fromWire(String? wire) => _fromWire(values, (v) => v.wire, wire);
}

/// The enum whose [wireOf] matches [wire], or null. Shared by the option enums
/// so a stored value from a future build falls back instead of throwing.
T? _fromWire<T>(List<T> values, String Function(T) wireOf, String? wire) {
  for (final v in values) {
    if (wireOf(v) == wire) return v;
  }
  return null;
}

/// The three knobs bundled, with the literary-tuned defaults. Handed to the
/// engine on every [ReflectionEngine.reflect] call.
final class ReflectionStyle {
  const ReflectionStyle({
    this.voice = ReflectionVoice.literary,
    this.length = ReflectionLength.sentences,
    this.specificity = ReflectionSpecificity.nameFreely,
  });

  final ReflectionVoice voice;
  final ReflectionLength length;
  final ReflectionSpecificity specificity;

  static const defaults = ReflectionStyle();

  Map<String, dynamic> toWire() => {
    'voice': voice.wire,
    'length': length.wire,
    'specificity': specificity.wire,
  };

  @override
  bool operator ==(Object other) =>
      other is ReflectionStyle &&
      other.voice == voice &&
      other.length == length &&
      other.specificity == specificity;

  @override
  int get hashCode => Object.hash(voice, length, specificity);
}
