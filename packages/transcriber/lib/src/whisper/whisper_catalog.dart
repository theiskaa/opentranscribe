import 'package:flutter/foundation.dart';

import 'package:transcriber/src/transcribe/transcription_engine.dart';

/// Where model files come from. The one host the app ever fetches from, and
/// the hosts its redirects may land on; the fetcher refuses everything else.
abstract final class WhisperHosts {
  static const modelHost = 'https://huggingface.co/ggerganov/whisper.cpp/resolve/main/';
  static const redirectSuffixes = ['huggingface.co', 'hf.co'];
}

/// One file the fetcher verifies: its name on the host, its length, and
/// its sha256.
@immutable
final class WhisperFile {
  const WhisperFile({required this.fileName, required this.bytes, required this.sha256});

  final String fileName;
  final int bytes;
  final String sha256;

  Uri get source => Uri.parse('${WhisperHosts.modelHost}$fileName');
}

/// One catalog entry: the picker facts plus what the fetcher verifies.
/// [budgetFactor] is how many times the audio's length a batch may take.
/// [languageCount] is how many of [whisperLanguageTags], in order, the model
/// carries a token for: the large-v3 family added Cantonese as the hundredth.
/// [encoder] is the zipped Core ML encoder whisper.cpp runs on the Neural
/// Engine when it finds [encoderDirName] beside the model file.
@immutable
final class WhisperModel {
  const WhisperModel({
    required this.option,
    required this.fileName,
    required this.sha256,
    required this.budgetFactor,
    required this.languageCount,
    required this.encoder,
  });

  final ModelOption option;
  final String fileName;
  final String sha256;
  final int budgetFactor;
  final int languageCount;
  final WhisperFile encoder;

  String get id => option.id;

  /// The model file as the fetcher verifies it.
  WhisperFile get file => WhisperFile(fileName: fileName, bytes: option.bytes, sha256: sha256);

  /// The directory the encoder zip unpacks to, the name whisper.cpp derives
  /// from the model file with its quantization suffix dropped.
  String get encoderDirName =>
      encoder.fileName.substring(0, encoder.fileName.length - '.zip'.length);

  /// Whether this model has a token for whisper's [code].
  bool speaks(String code) {
    final index = whisperLanguageIndex(code);
    return index != null && index < languageCount;
  }

  /// The tags this model lists, in catalog order.
  List<String> get supportedTags =>
      List.unmodifiable(whisperLanguageTags.values.take(languageCount));
}

const _mb = 1024 * 1024;

/// The models the app offers, in picker order. Sizes and hashes come from
/// tool/whisper/catalog.sh and change only through it.
const whisperCatalog = <WhisperModel>[
  WhisperModel(
    option: ModelOption(
      id: 'tiny-q5_1',
      displayName: 'Tiny',
      bytes: 32152673,
      quality: ModelQuality.basic,
      peakMemoryBytes: 250 * _mb,
      accelerationBytes: 15037446,
    ),
    fileName: 'ggml-tiny-q5_1.bin',
    sha256: '818710568da3ca15689e31a743197b520007872ff9576237bda97bd1b469c3d7',
    budgetFactor: 3,
    languageCount: 99,
    encoder: WhisperFile(
      fileName: 'ggml-tiny-encoder.mlmodelc.zip',
      bytes: 15037446,
      sha256: 'c88cbd2648e1f5415092bcf5256add463a0f19943e6938f46e8d4ffdebd47739',
    ),
  ),
  WhisperModel(
    option: ModelOption(
      id: 'base-q5_1',
      displayName: 'Base',
      bytes: 59707625,
      quality: ModelQuality.good,
      peakMemoryBytes: 350 * _mb,
      accelerationBytes: 37922638,
    ),
    fileName: 'ggml-base-q5_1.bin',
    sha256: '422f1ae452ade6f30a004d7e5c6a43195e4433bc370bf23fac9cc591f01a8898',
    budgetFactor: 3,
    languageCount: 99,
    encoder: WhisperFile(
      fileName: 'ggml-base-encoder.mlmodelc.zip',
      bytes: 37922638,
      sha256: '7e6ab77041942572f239b5b602f8aaa1c3ed29d73e3d8f20abea03a773541089',
    ),
  ),
  WhisperModel(
    option: ModelOption(
      id: 'small-q5_1',
      displayName: 'Small',
      bytes: 190085487,
      quality: ModelQuality.better,
      peakMemoryBytes: 650 * _mb,
      accelerationBytes: 163083239,
    ),
    fileName: 'ggml-small-q5_1.bin',
    sha256: 'ae85e4a935d7a567bd102fe55afc16bb595bdb618e11b2fc7591bc08120411bb',
    budgetFactor: 3,
    languageCount: 99,
    encoder: WhisperFile(
      fileName: 'ggml-small-encoder.mlmodelc.zip',
      bytes: 163083239,
      sha256: 'de43fb9fed471e95c19e60ae67575c2bf09e8fb607016da171b06ddad313988b',
    ),
  ),
  WhisperModel(
    option: ModelOption(
      id: 'medium-q5_0',
      displayName: 'Medium',
      bytes: 539212467,
      quality: ModelQuality.best,
      peakMemoryBytes: 1300 * _mb,
      accelerationBytes: 567829413,
    ),
    fileName: 'ggml-medium-q5_0.bin',
    sha256: '19fea4b380c3a618ec4723c3eef2eb785ffba0d0538cf43f8f235e7b3b34220f',
    budgetFactor: 6,
    languageCount: 99,
    encoder: WhisperFile(
      fileName: 'ggml-medium-encoder.mlmodelc.zip',
      bytes: 567829413,
      sha256: '79b0b8d436d47d3f24dd3afc91f19447dd686a4f37521b2f6d9c30a642133fbd',
    ),
  ),
  WhisperModel(
    option: ModelOption(
      id: 'large-v3-turbo-q5_0',
      displayName: 'Large Turbo',
      bytes: 574041195,
      quality: ModelQuality.top,
      peakMemoryBytes: 1400 * _mb,
      accelerationBytes: 1173393014,
    ),
    fileName: 'ggml-large-v3-turbo-q5_0.bin',
    sha256: '394221709cd5ad1f40c46e6031ca61bce88931e6e088c188294c6d5a55ffa7e2',
    budgetFactor: 6,
    languageCount: 100,
    encoder: WhisperFile(
      fileName: 'ggml-large-v3-turbo-encoder.mlmodelc.zip',
      bytes: 1173393014,
      sha256: '84bedfe895bd7b5de6e8e89a0803dfc5addf8c0c5bc4c937451716bf7cf7988a',
    ),
  ),
];

const whisperDefaultModelId = 'small-q5_1';

WhisperModel? whisperModelById(String id) {
  for (final model in whisperCatalog) {
    if (model.id == id) return model;
  }
  return null;
}

/// Every language whisper knows, by its own code, in whisper's own token
/// order (a model's [WhisperModel.languageCount] cuts this list), with the
/// one BCP-47 tag the engine lists and resolves to. `no` reads nb-NO to match
/// the Apple engines.
const whisperLanguageTags = <String, String>{
  'en': 'en-US',
  'zh': 'zh-CN',
  'de': 'de-DE',
  'es': 'es-ES',
  'ru': 'ru-RU',
  'ko': 'ko-KR',
  'fr': 'fr-FR',
  'ja': 'ja-JP',
  'pt': 'pt-BR',
  'tr': 'tr-TR',
  'pl': 'pl-PL',
  'ca': 'ca-ES',
  'nl': 'nl-NL',
  'ar': 'ar-SA',
  'sv': 'sv-SE',
  'it': 'it-IT',
  'id': 'id-ID',
  'hi': 'hi-IN',
  'fi': 'fi-FI',
  'vi': 'vi-VN',
  'he': 'he-IL',
  'uk': 'uk-UA',
  'el': 'el-GR',
  'ms': 'ms-MY',
  'cs': 'cs-CZ',
  'ro': 'ro-RO',
  'da': 'da-DK',
  'hu': 'hu-HU',
  'ta': 'ta-IN',
  'no': 'nb-NO',
  'th': 'th-TH',
  'ur': 'ur-PK',
  'hr': 'hr-HR',
  'bg': 'bg-BG',
  'lt': 'lt-LT',
  'la': 'la',
  'mi': 'mi-NZ',
  'ml': 'ml-IN',
  'cy': 'cy-GB',
  'sk': 'sk-SK',
  'te': 'te-IN',
  'fa': 'fa-IR',
  'lv': 'lv-LV',
  'bn': 'bn-BD',
  'sr': 'sr-RS',
  'az': 'az-AZ',
  'sl': 'sl-SI',
  'kn': 'kn-IN',
  'et': 'et-EE',
  'mk': 'mk-MK',
  'br': 'br-FR',
  'eu': 'eu-ES',
  'is': 'is-IS',
  'hy': 'hy-AM',
  'ne': 'ne-NP',
  'mn': 'mn-MN',
  'bs': 'bs-BA',
  'kk': 'kk-KZ',
  'sq': 'sq-AL',
  'sw': 'sw-KE',
  'gl': 'gl-ES',
  'mr': 'mr-IN',
  'pa': 'pa-IN',
  'si': 'si-LK',
  'km': 'km-KH',
  'sn': 'sn-ZW',
  'yo': 'yo-NG',
  'so': 'so-SO',
  'af': 'af-ZA',
  'oc': 'oc-FR',
  'ka': 'ka-GE',
  'be': 'be-BY',
  'tg': 'tg-TJ',
  'sd': 'sd-PK',
  'gu': 'gu-IN',
  'am': 'am-ET',
  'yi': 'yi',
  'lo': 'lo-LA',
  'uz': 'uz-UZ',
  'fo': 'fo-FO',
  'ht': 'ht-HT',
  'ps': 'ps-AF',
  'tk': 'tk-TM',
  'nn': 'nn-NO',
  'mt': 'mt-MT',
  'sa': 'sa-IN',
  'lb': 'lb-LU',
  'my': 'my-MM',
  'bo': 'bo-CN',
  'tl': 'tl-PH',
  'mg': 'mg-MG',
  'as': 'as-IN',
  'tt': 'tt-RU',
  'haw': 'haw-US',
  'ln': 'ln-CD',
  'ha': 'ha-NG',
  'ba': 'ba-RU',
  'jw': 'jv-ID',
  'su': 'su-ID',
  'yue': 'yue-HK',
};

/// Language subtags spelled differently by the platform than by whisper.
const _languageAliases = <String, String>{'nb': 'no', 'jv': 'jw', 'fil': 'tl', 'iw': 'he'};

/// The whisper code for a BCP-47 tag: by its language subtag, any region,
/// case-insensitive. Null when whisper has no such language, so a caller
/// refuses instead of transcribing as something else.
String? whisperLanguageCode(String tag) {
  final language = tag.toLowerCase().split('-').first;
  final code = _languageAliases[language] ?? language;
  return whisperLanguageTags.containsKey(code) ? code : null;
}

/// The position of whisper's [code] in its token order, or null.
int? whisperLanguageIndex(String code) {
  var index = 0;
  for (final known in whisperLanguageTags.keys) {
    if (known == code) return index;
    index++;
  }
  return null;
}

/// The tag the engine lists for a request, or null when unsupported.
String? whisperResolvedTag(String tag) {
  final code = whisperLanguageCode(tag);
  return code == null ? null : whisperLanguageTags[code];
}
