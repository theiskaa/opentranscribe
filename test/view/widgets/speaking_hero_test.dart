import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/state/engines_cubit.dart';
import 'package:opentranscribe/core/state/settings_cubit.dart';
import 'package:opentranscribe/view/widgets/speaking_hero.dart';

import '../../support/engine_fixtures.dart';

void main() {
  final engines = [
    EngineRowState(
      descriptor: engineDescriptor('speech', displayName: 'SpeechAnalyzer'),
      available: true,
      isActive: false,
    ),
    EngineRowState(
      descriptor: engineDescriptor('whisper', displayName: 'Whisper'),
      available: true,
      isActive: true,
    ),
  ];

  test('the ready line names the engine the languages describe, not the active row', () {
    const state = SettingsState(engineId: 'speech');
    expect(heroEngineName(engines, state, settled: true), 'SpeechAnalyzer');
  });

  test('until the model half agrees on the engine, no engine is named', () {
    const state = SettingsState(engineId: 'whisper');
    expect(heroEngineName(engines, state, settled: false), isNull);
  });

  test('an engine the rows do not carry names nothing', () {
    const state = SettingsState(engineId: 'dictation');
    expect(heroEngineName(engines, state, settled: true), isNull);
  });
}
