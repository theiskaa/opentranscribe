import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcriber/src/whisper/platform_model_storage.dart';

/// Pins the channel contract with AudioCapture.swift for the models directory
/// and the memory probe.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const methods = MethodChannel('transcriber/audio');

  late PlatformModelStorage storage;

  setUp(() => storage = PlatformModelStorage());
  tearDown(() => messenger.setMockMethodCallHandler(methods, null));

  void mockMethods(Future<Object?> Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(methods, handler);
  }

  test('the models directory is the path the platform answers', () async {
    mockMethods((call) async {
      expect(call.method, 'modelsDirectory');
      return '/support/models';
    });

    expect((await storage.modelsDirectory()).path, '/support/models');
  });

  test('a platform that cannot provide the directory throws a file system failure', () async {
    mockMethods((call) async => throw PlatformException(code: 'storage_failed', message: 'ro'));

    await expectLater(storage.modelsDirectory(), throwsA(isA<FileSystemException>()));
  });

  test('an empty directory answer is refused rather than used', () async {
    mockMethods((call) async => '');

    await expectLater(storage.modelsDirectory(), throwsA(isA<FileSystemException>()));
  });

  test('physical memory reads the platform figure and answers null when it cannot', () async {
    mockMethods((call) async => 6 * 1024 * 1024 * 1024);
    expect(await storage.physicalMemoryBytes(), 6 * 1024 * 1024 * 1024);

    mockMethods((call) async => 0);
    expect(await storage.physicalMemoryBytes(), isNull);

    mockMethods((call) async => throw PlatformException(code: 'x'));
    expect(await storage.physicalMemoryBytes(), isNull);
  });

  test('a missing plugin answers null memory and no directory', () async {
    expect(await storage.physicalMemoryBytes(), isNull);
    await expectLater(storage.modelsDirectory(), throwsA(isA<FileSystemException>()));
  });
}
