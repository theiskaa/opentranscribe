import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/services/model_usage.dart';
import 'package:transcriber/testing.dart';

void main() {
  test('installed model bytes sum every choice engine and skip the rest', () async {
    final choice = FakeModelChoiceEngine(installed: {'small', 'large'});
    final other = FakeModelChoiceEngine(installed: {'small'});

    expect(await installedModelBytes([FakeBatchEngine(), choice, other]), 100 + 500 + 100);
  });

  test('no downloaded model is zero bytes', () async {
    expect(await installedModelBytes([FakeBatchEngine(), FakeModelChoiceEngine()]), 0);
  });
}
