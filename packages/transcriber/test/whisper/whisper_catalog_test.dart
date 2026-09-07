import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/src/transcribe/transcription_engine.dart';
import 'package:transcriber/src/whisper/whisper_catalog.dart';

void main() {
  test('every entry names a file matching its id, a full sha256, and a peak above its size', () {
    for (final model in whisperCatalog) {
      expect(model.fileName, 'ggml-${model.id}.bin');
      expect(model.sha256, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(model.option.bytes, greaterThan(0));
      expect(model.option.peakMemoryBytes, greaterThan(model.option.bytes));
    }
  });

  test('every encoder is the zipped Core ML directory whisper.cpp derives from the model file', () {
    for (final model in whisperCatalog) {
      final stem = model.fileName.substring(0, model.fileName.length - '.bin'.length);
      final unquantized = stem.substring(0, stem.lastIndexOf('-'));
      expect(model.encoderDirName, '$unquantized-encoder.mlmodelc');
      expect(model.encoder.fileName, '${model.encoderDirName}.zip');
      expect(model.encoder.bytes, greaterThan(0));
      expect(model.option.accelerationBytes, model.encoder.bytes);
      expect(model.encoder.sha256, hasLength(64));
      expect(model.encoder.source.host, 'huggingface.co');
    }
  });

  test('ids are unique and the default is one of them', () {
    final ids = whisperCatalog.map((m) => m.id).toSet();
    expect(ids, hasLength(whisperCatalog.length));
    expect(whisperModelById(whisperDefaultModelId), isNotNull);
    expect(whisperModelById('nope'), isNull);
  });

  test('quality rises through the catalog in picker order', () {
    final qualities = whisperCatalog.map((m) => m.option.quality.index).toList();
    expect(qualities, orderedEquals([...qualities]..sort()));
    expect(whisperCatalog.first.option.quality, ModelQuality.basic);
    expect(whisperCatalog.last.option.quality, ModelQuality.top);
  });

  test('a model source lives on the pinned host', () {
    for (final model in whisperCatalog) {
      expect(model.source.toString(), startsWith(WhisperHosts.modelHost));
      expect(model.source.host, 'huggingface.co');
    }
  });

  test('every model but the large-v3 family stops short of Cantonese, the hundredth', () {
    expect(whisperLanguageIndex('en'), 0);
    expect(whisperLanguageIndex('yue'), 99);
    expect(whisperLanguageIndex('xx'), isNull);
    for (final model in whisperCatalog) {
      expect(model.speaks('en'), isTrue, reason: model.id);
      expect(model.speaks('ka'), isTrue, reason: model.id);
      expect(model.speaks('yue'), model.languageCount == 100, reason: model.id);
      expect(model.supportedTags, hasLength(model.languageCount));
    }
    expect(whisperModelById('large-v3-turbo-q5_0')!.speaks('yue'), isTrue);
    expect(whisperModelById(whisperDefaultModelId)!.speaks('yue'), isFalse);
  });

  test('whisper knows one hundred languages, each with one tag', () {
    expect(whisperLanguageTags, hasLength(100));
    final tags = whisperLanguageTags.values.toSet();
    expect(tags, hasLength(100));
    for (final entry in whisperLanguageTags.entries) {
      expect(entry.value.toLowerCase().split('-').first, anyOf(entry.key, 'nb', 'jv'));
    }
  });

  test('a tag resolves by its language subtag, any region, any case', () {
    expect(whisperLanguageCode('de-AT'), 'de');
    expect(whisperLanguageCode('EN-gb'), 'en');
    expect(whisperLanguageCode('ka-GE'), 'ka');
    expect(whisperLanguageCode('la'), 'la');
    expect(whisperResolvedTag('de-AT'), 'de-DE');
    expect(whisperResolvedTag('zh-TW'), 'zh-CN');
  });

  test('platform spellings of a language map onto whisper codes', () {
    expect(whisperLanguageCode('nb-NO'), 'no');
    expect(whisperResolvedTag('nb-NO'), 'nb-NO');
    expect(whisperLanguageCode('jv-ID'), 'jw');
    expect(whisperResolvedTag('jw'), 'jv-ID');
    expect(whisperLanguageCode('fil-PH'), 'tl');
    expect(whisperLanguageCode('iw-IL'), 'he');
  });

  test('an unknown language answers null rather than a guess', () {
    expect(whisperLanguageCode('xx-XX'), isNull);
    expect(whisperResolvedTag('eo'), isNull);
  });
}
