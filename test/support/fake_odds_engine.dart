import 'dart:io';

import 'package:transcriber/testing.dart';
import 'package:transcriber/transcriber.dart';

/// Canned odds for an engine that can tell two languages apart: the second
/// of the two asked is heard at [secondOdds] of a stretch's start and the
/// first at the rest; [unreadable] answers nothing for either; [hold] keeps
/// every question open. Every question lands in [asked], with the file it was
/// about.
mixin _CannedOdds implements LanguageOddsEngine {
  double Function(Duration start) get secondOdds;
  bool get unreadable => false;
  Future<void>? get hold => null;
  List<({String path, Duration start, Duration end})> get asked;

  @override
  Future<Map<String, double>> languageOdds(
    File audio, {
    required Duration start,
    required Duration end,
    required List<String> among,
  }) async {
    asked.add((path: audio.path, start: start, end: end));
    final held = hold;
    if (held != null) await held;
    if (unreadable) return {for (final tag in among) tag: 0};
    final second = secondOdds(start);
    return {among.first: 1 - second, among.last: second};
  }
}

/// A batch engine that can also tell two languages apart ([_CannedOdds]).
class FakeOddsEngine extends FakeBatchEngine with _CannedOdds {
  FakeOddsEngine({this.secondOdds = _undecided, this.unreadable = false, this.hold});

  static double _undecided(Duration _) => 0.5;

  @override
  final double Function(Duration start) secondOdds;
  @override
  final bool unreadable;
  @override
  final Future<void>? hold;
  @override
  final List<({String path, Duration start, Duration end})> asked = [];
}

/// A paced model-choice engine, its model on the device, that can tell two
/// languages apart ([_CannedOdds]).
class FakePacedOddsEngine extends FakeModelChoiceEngine with _CannedOdds {
  FakePacedOddsEngine({required this.secondOdds})
    : super(installed: const {'small'}, supportedLocaleTags: const ['en-US', 'fr-FR']);

  @override
  final double Function(Duration start) secondOdds;
  @override
  final List<({String path, Duration start, Duration end})> asked = [];
}

/// A managed engine that can tell two languages apart, for the model-install
/// side of a question: [installed] as [FakeManagedEngine] keeps it, and every
/// question, answered as the second language, lands in [asked].
class FakeManagedOddsEngine extends FakeManagedEngine with _CannedOdds {
  FakeManagedOddsEngine() : super(supportedLocaleTags: const ['en-US', 'fr-FR']);

  static double _second(Duration _) => 1;

  @override
  double Function(Duration start) get secondOdds => _second;
  @override
  final List<({String path, Duration start, Duration end})> asked = [];
}
