import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/view/layouts/onboarding/components/scene_clock.dart';

void main() {
  const length = Duration(seconds: 42);

  test('under Reduce Motion the clock parks on its last frame and never ticks', () {
    final clock = SceneClock(length: length, vsync: const TestVSync(), reduceMotion: true);
    expect(clock.elapsed, length);
    var ticks = 0;
    clock.addListener(() => ticks++);
    expect(ticks, 0);
    clock.dispose();
  });
}
