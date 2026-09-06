import 'dart:io';

import 'package:transcriber/src/whisper/model_storage.dart';

/// Deterministic [ModelStorage] for tests: a directory the test owns and a
/// memory figure it chooses (null for a platform that cannot say).
class FakeModelStorage implements ModelStorage {
  FakeModelStorage({required this.directory, this.memoryBytes});

  final Directory directory;
  final int? memoryBytes;

  @override
  Future<Directory> modelsDirectory() async => directory..createSync(recursive: true);

  @override
  Future<int?> physicalMemoryBytes() async => memoryBytes;
}
