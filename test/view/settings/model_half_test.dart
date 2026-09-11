import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/state/models_cubit.dart';
import 'package:opentranscribe/view/layouts/settings/screens/models_screen.dart';

void main() {
  const whisper = ModelsState(
    engineId: 'whisper',
    offersModelChoice: true,
    offersAcceleration: true,
  );

  test('the model half shows once the models describe the languages\' engine', () {
    final half = modelHalf(whisper, languagesEngineId: 'whisper');

    expect(half.settled, isTrue);
    expect(half.choice, isTrue);
    expect(half.acceleration, isTrue);
  });

  test('mid-switch the model half hides whatever the models still offer', () {
    final half = modelHalf(whisper, languagesEngineId: 'apple');

    expect(half.settled, isFalse);
    expect(half.choice, isFalse);
    expect(half.acceleration, isFalse);
  });

  test('a settled engine without a choice shows neither the cards nor the switch', () {
    final half = modelHalf(const ModelsState(engineId: 'apple'), languagesEngineId: 'apple');

    expect(half.settled, isTrue);
    expect(half.choice, isFalse);
    expect(half.acceleration, isFalse);
  });
}
