import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/state/models_cubit.dart';
import 'package:opentranscribe/core/state/settings_cubit.dart';
import 'package:opentranscribe/view/layouts/settings/screens/models_screen.dart';

void main() {
  const whisperLanguages = SettingsState(engineId: 'whisper');
  const whisperModels = ModelsState(engineId: 'whisper', offersModelChoice: true);
  const speechLanguages = SettingsState(engineId: 'speech');
  const speechModels = ModelsState(engineId: 'speech');
  const seenWhisper = (languages: whisperLanguages, models: whisperModels);

  test('a settled engine draws its live halves and takes touches', () {
    final face = enginePaneFace(
      engineId: 'whisper',
      active: true,
      languages: whisperLanguages,
      models: whisperModels,
      seen: null,
    );
    expect(face.halves?.languages, same(whisperLanguages));
    expect(face.halves?.models, same(whisperModels));
    expect(face.live, isTrue);
  });

  test('mid-switch the models still describing the old engine give way to the last picture', () {
    const freshLanguages = SettingsState(engineId: 'whisper', localeId: 'de-DE');
    final face = enginePaneFace(
      engineId: 'whisper',
      active: true,
      languages: freshLanguages,
      models: speechModels,
      seen: seenWhisper,
    );
    expect(face.halves?.languages, same(freshLanguages));
    expect(face.halves?.models, same(whisperModels));
    expect(face.live, isFalse);
  });

  test('an engine seen before draws its picture while another is in use', () {
    final face = enginePaneFace(
      engineId: 'whisper',
      active: false,
      languages: speechLanguages,
      models: speechModels,
      seen: seenWhisper,
    );
    expect(face.halves, seenWhisper);
    expect(face.live, isFalse);
  });

  test('an engine never seen draws nothing until both of its halves are known', () {
    final languagesOnly = enginePaneFace(
      engineId: 'whisper',
      active: true,
      languages: whisperLanguages,
      models: speechModels,
      seen: null,
    );
    expect(languagesOnly.halves, isNull);
    final neither = enginePaneFace(
      engineId: 'whisper',
      active: false,
      languages: speechLanguages,
      models: speechModels,
      seen: null,
    );
    expect(neither.halves, isNull);
  });

  test('the engine in use stays touchable on its last languages after their load failed', () {
    const stale = SettingsState(engineId: 'speech', loadFailed: true);
    final face = enginePaneFace(
      engineId: 'whisper',
      active: true,
      languages: stale,
      models: whisperModels,
      seen: seenWhisper,
    );
    expect(face.halves?.languages, same(whisperLanguages));
    expect(face.live, isTrue);
  });

  test('a failed languages load never makes a pane touchable on another engine models', () {
    const stale = SettingsState(engineId: 'speech', loadFailed: true);
    final face = enginePaneFace(
      engineId: 'whisper',
      active: true,
      languages: stale,
      models: speechModels,
      seen: seenWhisper,
    );
    expect(face.live, isFalse);
  });
}
