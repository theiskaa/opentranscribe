import 'package:flutter/services.dart';

/// Semantic haptics over the engine's [HapticFeedback]. No plugin. Call sites
/// name the intent, not the impact strength, so the vocabulary stays small:
/// [light] on press, [selection] on tab/day switches, [medium] on destructive
/// confirms.
abstract final class Haptics {
  static void light() => HapticFeedback.lightImpact();

  static void medium() => HapticFeedback.mediumImpact();

  static void selection() => HapticFeedback.selectionClick();
}
