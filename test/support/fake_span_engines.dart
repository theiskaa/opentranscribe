import 'dart:async';
import 'dart:io';

import 'package:transcriber/testing.dart';
import 'package:transcriber/transcriber.dart';

/// A batch engine whose every run lands the language it ran in, as
/// [words] has it (its bare subtag by default: "fr" for fr-FR).
FakeBatchEngine languageNamed([String Function(String locale)? words]) =>
    FakeBatchEngine()
      ..transcriptBuilder = (locale, start, end) => words?.call(locale) ?? locale.split('-').first;

/// A batch engine whose runs in [hungLocale] never finish, for a span a
/// timeout has to give up on; every other run lands as [FakeBatchEngine]'s.
class FakeHungSpanEngine extends FakeBatchEngine {
  FakeHungSpanEngine(this.hungLocale);

  final String hungLocale;

  @override
  Future<Transcript> transcribeFile(
    File audio, {
    required String localeId,
    Duration? start,
    Duration? end,
  }) {
    if (localeId != hungLocale) {
      return super.transcribeFile(audio, localeId: localeId, start: start, end: end);
    }
    batchCalls.add((localeId: localeId, start: start, end: end));
    return Completer<Transcript>().future;
  }
}

/// A batch engine that reports each run halfway through before it lands or
/// fails as [FakeBatchEngine] does, so a pass's line can be followed.
class FakeProgressEngine extends FakeBatchEngine implements ProgressBatchEngine {
  @override
  Future<Transcript> transcribeFileWithProgress(
    File audio, {
    required String localeId,
    required void Function(double fraction) onProgress,
    Duration? start,
    Duration? end,
  }) {
    onProgress(0.5);
    return transcribeFile(audio, localeId: localeId, start: start, end: end);
  }
}
