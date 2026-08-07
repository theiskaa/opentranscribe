/// The closed set of reflection failures. A reflection has exactly two
/// non-failure outcomes: text, or silence (null from [ReflectionEngine.reflect]).
/// This taxonomy is only for the third case, when the engine could not run at
/// all, so a caller retries later rather than persisting a false silence.
sealed class ReflectionException implements Exception {
  const ReflectionException([this.message]);

  final String? message;

  @override
  String toString() => message == null ? '$runtimeType' : '$runtimeType: $message';
}

/// The engine could not produce a reflection this time (the model was not
/// usable, a channel error, an unexpected generation failure). Transient by
/// contract: distinct from silence, which is a definitive "nothing to say".
/// A guardrail refusal is NOT this; that is silence.
class ReflectionUnavailable extends ReflectionException {
  const ReflectionUnavailable([super.message]);
}
