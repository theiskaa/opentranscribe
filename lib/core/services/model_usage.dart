import 'package:transcriber/transcriber.dart';

/// The bytes every engine's downloaded models hold on disk, active or not,
/// their acceleration files included: a file stays where it is when the
/// user switches engines, so the Cache screen counts it regardless. Engines
/// without a choice hold nothing here.
Future<int> installedModelBytes(Iterable<TranscriptionEngine> engines) async {
  var total = 0;
  for (final engine in engines) {
    if (engine is! ModelChoiceEngine) continue;
    final installed = await engine.installedModels();
    final accelerated = engine is AcceleratedModelEngine
        ? await engine.acceleratedModels()
        : const <String>{};
    for (final model in engine.models) {
      if (installed.contains(model.id)) total += model.bytes;
      if (accelerated.contains(model.id)) total += model.accelerationBytes;
    }
  }
  return total;
}
