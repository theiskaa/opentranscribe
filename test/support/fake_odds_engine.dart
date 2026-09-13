import 'dart:io';

import 'package:transcriber/testing.dart';
import 'package:transcriber/transcriber.dart';

/// A batch engine that can also tell two languages apart: the second of the
/// two asked is heard at [secondOdds] of a stretch's start and the first at
/// the rest; [unreadable] answers nothing for either; [hold] keeps every
/// question open. Every question lands in [asked], with the file it was
/// about.
class FakeOddsEngine extends FakeBatchEngine implements LanguageOddsEngine {
  FakeOddsEngine({this.secondOdds = _undecided, this.unreadable = false, this.hold});

  static double _undecided(Duration _) => 0.5;

  final double Function(Duration start) secondOdds;
  final bool unreadable;
  final Future<void>? hold;
  final List<({String path, Duration start, Duration end})> asked = [];

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

/// A managed engine that can tell two languages apart, for the model-install
/// side of a question: [installed] as [FakeManagedEngine] keeps it, and every
/// question lands in [asked].
class FakeManagedOddsEngine extends FakeManagedEngine implements LanguageOddsEngine {
  FakeManagedOddsEngine() : super(supportedLocaleTags: const ['en-US', 'fr-FR']);

  final List<({String path, Duration start, Duration end})> asked = [];

  @override
  Future<Map<String, double>> languageOdds(
    File audio, {
    required Duration start,
    required Duration end,
    required List<String> among,
  }) async {
    asked.add((path: audio.path, start: start, end: end));
    return {among.first: 0, among.last: 1};
  }
}
