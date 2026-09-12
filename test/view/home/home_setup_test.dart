import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/state/engines_cubit.dart';
import 'package:opentranscribe/core/state/models_cubit.dart';
import 'package:opentranscribe/core/state/settings_cubit.dart';
import 'package:opentranscribe/view/layouts/home/components/home_setup.dart';
import 'package:opentranscribe/view/widgets/model_card.dart';
import 'package:transcriber/transcriber.dart';

import '../../support/engine_fixtures.dart';

void main() {
  EngineRowState engine(String id, {bool active = false, bool available = true}) =>
      EngineRowState(descriptor: engineDescriptor(id), available: available, isActive: active);

  final engines = [engine('speech', active: true), engine('dictation'), engine('whisper')];

  LanguageModelState language({
    ModelAssetStatus status = ModelAssetStatus.installed,
    bool reserved = true,
    LanguageFailure? failure,
  }) => LanguageModelState(
    tag: 'en-US',
    status: status,
    reserved: reserved,
    isDefault: true,
    failure: failure,
  );

  SettingsState apple(LanguageModelState row, {bool managed = true}) => SettingsState(
    localeId: 'en-US',
    engineId: 'speech',
    managesModels: managed,
    languages: [row],
  );

  SettingsState whisperLanguages([LanguageModelState? row]) => SettingsState(
    localeId: 'en-US',
    engineId: 'whisper',
    managesModels: true,
    offersModelChoice: true,
    languages: [row ?? language()],
  );

  const noChoice = ModelsState(engineId: 'speech');

  ModelsState whisperModels({
    bool installed = true,
    bool heavy = false,
    ModelInstallReason? failure,
    String engineId = 'whisper',
  }) => ModelsState(
    engineId: engineId,
    offersModelChoice: true,
    models: [
      ModelRowState(
        option: const ModelOption(
          id: 'small',
          displayName: 'Small',
          bytes: 100,
          quality: ModelQuality.better,
          peakMemoryBytes: 1000,
        ),
        installed: installed,
        selected: true,
        heavy: heavy,
        failure: failure,
      ),
    ],
  );

  ({bool picker, bool model, HomeSetupLine line}) face(
    SettingsState languages,
    ModelsState models, {
    bool opened = false,
    List<EngineRowState>? rows,
  }) {
    final face = homeSetupFace(
      engines: rows ?? engines,
      languages: languages,
      models: models,
      choice: modelHalf(models, languagesEngineId: languages.engineId).choice,
      opened: opened,
    );
    return (picker: face.showsPicker, model: face.modelCard != null, line: face.line);
  }

  group('under an engine with a model per language', () {
    test('a ready language is one quiet card and the way to record', () {
      expect(face(apple(language()), noChoice), (
        picker: false,
        model: false,
        line: HomeSetupLine.record,
      ));
    });

    test('Change opens the picker, and there is no model card to show', () {
      expect(face(apple(language()), noChoice, opened: true), (
        picker: true,
        model: false,
        line: HomeSetupLine.record,
      ));
    });

    test('a language still to download stays quiet, the first take fetches it', () {
      final row = language(status: ModelAssetStatus.supported, reserved: false);
      expect(face(apple(row), noChoice), (picker: false, model: false, line: HomeSetupLine.record));
    });

    test('a language with a failure story opens the picker and asks for the fix first', () {
      final row = language(status: ModelAssetStatus.unsupported, reserved: false);
      expect(face(apple(row), noChoice), (
        picker: true,
        model: false,
        line: HomeSetupLine.fixFirst,
      ));
    });

    test('an engine without downloads is stuck on an unready language', () {
      final row = language(status: ModelAssetStatus.supported);
      expect(face(apple(row, managed: false), noChoice), (
        picker: true,
        model: false,
        line: HomeSetupLine.fixFirst,
      ));
    });

    test('an engine that cannot run here opens the picker and asks for the fix first', () {
      final rows = [engine('speech', active: true, available: false), engine('whisper')];
      expect(face(apple(language()), noChoice, rows: rows), (
        picker: true,
        model: false,
        line: HomeSetupLine.fixFirst,
      ));
    });
  });

  group('under one model for every language', () {
    test('a model on the phone is as quiet as a ready language', () {
      expect(face(whisperLanguages(), whisperModels()), (
        picker: false,
        model: false,
        line: HomeSetupLine.record,
      ));
    });

    test('Change opens the picker and the model card together', () {
      expect(face(whisperLanguages(), whisperModels(), opened: true), (
        picker: true,
        model: true,
        line: HomeSetupLine.record,
      ));
    });

    test('a model not downloaded opens both, and says recording works meanwhile', () {
      expect(face(whisperLanguages(), whisperModels(installed: false)), (
        picker: true,
        model: true,
        line: HomeSetupLine.modelLands,
      ));
    });

    test('a failed download keeps the card open for its retry, which comes first', () {
      final models = whisperModels(installed: false, failure: ModelInstallReason.offline);
      expect(face(whisperLanguages(), models), (
        picker: true,
        model: true,
        line: HomeSetupLine.fixFirst,
      ));
    });

    test('a model that would not open asks for its fix before a take', () {
      final models = whisperModels(failure: ModelInstallReason.loadFailed);
      expect(face(whisperLanguages(), models), (
        picker: true,
        model: true,
        line: HomeSetupLine.fixFirst,
      ));
    });

    test('a failed Neural Engine file leaves the installed model quiet, it runs without one', () {
      final models = whisperModels(failure: ModelInstallReason.offline);
      expect(face(whisperLanguages(), models), (
        picker: false,
        model: false,
        line: HomeSetupLine.record,
      ));
    });

    test('a model already on the phone runs even where downloading it would be too heavy', () {
      expect(face(whisperLanguages(), whisperModels(heavy: true)), (
        picker: false,
        model: false,
        line: HomeSetupLine.record,
      ));
    });

    test('a model this phone cannot hold asks for another first', () {
      expect(
        face(whisperLanguages(), whisperModels(installed: false, heavy: true)).line,
        HomeSetupLine.fixFirst,
      );
    });

    test("the model's own failure mirrored onto the language is the card's to tell", () {
      final row = language(
        status: ModelAssetStatus.supported,
        failure: const LanguageFailure(kind: LanguageFailureKind.installFailed),
      );
      expect(
        face(whisperLanguages(row), whisperModels(installed: false)).line,
        HomeSetupLine.modelLands,
      );
    });

    test('a language the model cannot hear asks for the fix first', () {
      final row = language(status: ModelAssetStatus.unsupported, reserved: false);
      expect(face(whisperLanguages(row), whisperModels()).line, HomeSetupLine.fixFirst);
    });

    test('mid switch, before the models describe the new engine, no model card lands', () {
      final models = whisperModels(installed: false, engineId: 'speech');
      expect(face(whisperLanguages(), models), (
        picker: false,
        model: false,
        line: HomeSetupLine.record,
      ));
    });
  });
}
