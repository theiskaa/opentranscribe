import 'package:flutter_test/flutter_test.dart';

import 'package:opentranscribe/core/state/settings_cubit.dart';
import 'package:opentranscribe/core/transcribe/transcription_engine.dart';
import 'package:opentranscribe/view/layouts/settings/components/model_failure_story.dart';

void main() {
  LanguageModelState row({
    ModelAssetStatus status = ModelAssetStatus.supported,
    LanguageFailure? failure,
    double? installFraction,
  }) => LanguageModelState(
    tag: 'en-US',
    status: status,
    reserved: false,
    isDefault: false,
    failure: failure,
    installFraction: installFraction,
  );

  group('modelFailureCase', () {
    test('a cap failure asks for an eviction, never a retry', () {
      final r = row(failure: const LanguageFailure(kind: LanguageFailureKind.capReached));
      expect(modelFailureCase(r), ModelFailureCase.cap);
    });

    test('a refused removal keeps its own story on a ready row', () {
      final r = row(failure: const LanguageFailure(kind: LanguageFailureKind.removeFailed));
      expect(modelFailureCase(r), ModelFailureCase.removeFailed);
    });

    test('an install that failed on an unsupported asset says unsupported', () {
      final r = row(
        failure: const LanguageFailure(
          kind: LanguageFailureKind.installFailed,
          assetStatus: ModelAssetStatus.unsupported,
        ),
      );
      expect(modelFailureCase(r), ModelFailureCase.unsupported);
    });

    test('an install that failed over a pending system download says stuck', () {
      final r = row(
        failure: const LanguageFailure(
          kind: LanguageFailureKind.installFailed,
          assetStatus: ModelAssetStatus.downloading,
        ),
      );
      expect(modelFailureCase(r), ModelFailureCase.stuck);
    });

    test('an install failure with no asset story is generic', () {
      final r = row(failure: const LanguageFailure(kind: LanguageFailureKind.installFailed));
      expect(modelFailureCase(r), ModelFailureCase.generic);
    });

    test('an unsupported row needs no failure to tell its story', () {
      expect(
        modelFailureCase(row(status: ModelAssetStatus.unsupported)),
        ModelFailureCase.unsupported,
      );
    });

    test('a system download nobody here started reads as stuck', () {
      expect(modelFailureCase(row(status: ModelAssetStatus.downloading)), ModelFailureCase.stuck);
    });
  });

  group('rowHasFailureStory', () {
    test('a plain supported row has nothing to explain', () {
      expect(rowHasFailureStory(row()), isFalse);
    });

    test('this app\'s own in-flight download is progress, not a story', () {
      expect(
        rowHasFailureStory(row(status: ModelAssetStatus.downloading, installFraction: 0.4)),
        isFalse,
      );
    });

    test('a stranded system download, an unsupported language, and any failure all explain', () {
      expect(rowHasFailureStory(row(status: ModelAssetStatus.downloading)), isTrue);
      expect(rowHasFailureStory(row(status: ModelAssetStatus.unsupported)), isTrue);
      expect(
        rowHasFailureStory(
          row(failure: const LanguageFailure(kind: LanguageFailureKind.installFailed)),
        ),
        isTrue,
      );
    });
  });
}
