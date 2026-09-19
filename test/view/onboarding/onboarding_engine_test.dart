import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/state/engines_cubit.dart';
import 'package:opentranscribe/core/state/models_cubit.dart';
import 'package:opentranscribe/view/layouts/onboarding/components/onboarding_engine.dart';
import 'package:transcriber/transcriber.dart';

import '../../support/engine_fixtures.dart';

void main() {
  EngineRowState engine(
    String id, {
    bool live = true,
    bool available = true,
    bool active = false,
  }) => EngineRowState(
    descriptor: engineDescriptor(id),
    available: available,
    isActive: active,
    live: live,
  );

  ModelRowState model(
    String id, {
    bool selected = false,
    bool installed = false,
    bool heavy = false,
    double? installFraction,
  }) => ModelRowState(
    option: ModelOption(
      id: id,
      displayName: id,
      bytes: 100,
      quality: ModelQuality.good,
      peakMemoryBytes: 1000,
    ),
    installed: installed,
    selected: selected,
    heavy: heavy,
    installFraction: installFraction,
  );

  final rows = [
    engine('speech', active: true),
    engine('whisper', live: false),
    engine('dictation'),
  ];

  test('an engine that shows words live answers as you speak, the rest after you stop', () {
    expect(wordsWhenOf(rows[0]), WordsWhen.asYouSpeak);
    expect(wordsWhenOf(rows[1]), WordsWhen.afterYouStop);
    expect(enginesAnswering(rows, WordsWhen.asYouSpeak).map((r) => r.descriptor.engineId), [
      'speech',
      'dictation',
    ]);
    expect(enginesAnswering(rows, WordsWhen.afterYouStop).map((r) => r.descriptor.engineId), [
      'whisper',
    ]);
  });

  test('an answer stands for the first engine that runs here, in registry order', () {
    expect(engineForAnswer(rows, WordsWhen.asYouSpeak), 'speech');
    expect(engineForAnswer(rows, WordsWhen.afterYouStop), 'whisper');
  });

  test('where the first live engine cannot run, as you speak falls to the next one', () {
    final older = [engine('speech', available: false), rows[1], rows[2]];
    expect(engineForAnswer(older, WordsWhen.asYouSpeak), 'dictation');
  });

  test('an answer with nothing that runs here stands for no engine', () {
    final noWhisper = [rows[0], engine('whisper', live: false, available: false), rows[2]];
    expect(engineForAnswer(noWhisper, WordsWhen.afterYouStop), isNull);
  });

  test('the selected model stays when this phone can hold it', () {
    expect(
      fittingModelId([model('base'), model('small', selected: true), model('medium')]),
      'small',
    );
  });

  test('a selected model too large for this phone gives way to the largest that fits', () {
    expect(
      fittingModelId([
        model('tiny'),
        model('base'),
        model('small', selected: true, heavy: true),
        model('medium', heavy: true),
      ]),
      'base',
    );
  });

  test('a too-large model already on the phone stays chosen', () {
    expect(
      fittingModelId([model('base'), model('small', selected: true, heavy: true, installed: true)]),
      'small',
    );
  });

  test('no selection, or nothing that fits, settles on no model', () {
    expect(fittingModelId([model('base'), model('small')]), isNull);
    expect(fittingModelId([model('small', selected: true, heavy: true)]), isNull);
  });

  test('a selection that fits needs no swap, and one too large swaps to the largest that fits', () {
    ModelsState state(List<ModelRowState> models) =>
        ModelsState(engineId: 'whisper', offersModelChoice: true, models: models);

    expect(modelSwap(state([model('base'), model('small', selected: true)])), isNull);
    expect(modelSwap(state([model('base'), model('small', selected: true, heavy: true)])), 'base');
    expect(modelSwap(state(const [])), isNull);
  });

  test('leaving the page downloads a chosen model that is not here, not coming, and fits', () {
    ModelsState state(ModelRowState row, {bool choice = true}) =>
        ModelsState(engineId: 'whisper', offersModelChoice: choice, models: [row]);

    expect(downloadsOnLeave(state(model('small', selected: true))), isTrue);
    expect(downloadsOnLeave(state(model('small', selected: true, installed: true))), isFalse);
    expect(downloadsOnLeave(state(model('small', selected: true, installFraction: 0.2))), isFalse);
    expect(downloadsOnLeave(state(model('small', selected: true, heavy: true))), isFalse);
    expect(downloadsOnLeave(state(model('small', selected: true), choice: false)), isFalse);
    expect(downloadsOnLeave(state(model('small'))), isFalse);
  });

  test('a word is hidden before it lands, fades in over its fade, then stays', () {
    const landing = Duration(seconds: 1);
    const fade = Duration(milliseconds: 200);
    expect(landedFraction(Duration.zero, landing, fade: fade), 0);
    expect(
      landedFraction(const Duration(milliseconds: 1100), landing, fade: fade),
      closeTo(0.5, 1e-9),
    );
    expect(landedFraction(const Duration(seconds: 3), landing, fade: fade), 1);
  });
}
