import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:opentranscribe/core/app/storage_key.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const methods = MethodChannel('opentranscribe/storage_key');

  late StorageKey storageKey;

  setUp(() {
    storageKey = StorageKey();
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(methods, null);
  });

  void mockMethods(Future<Object?> Function(MethodCall call) handler) {
    messenger.setMockMethodCallHandler(methods, handler);
  }

  test('decodes the base64 payload into 32 raw bytes', () async {
    final bytes = Uint8List.fromList(List.generate(32, (i) => i));
    mockMethods((call) async {
      expect(call.method, 'obtain');
      return base64Encode(bytes);
    });

    expect(await storageKey.obtain(), bytes);
  });

  test('a wrong-length payload throws StorageKeyException', () async {
    mockMethods((call) async => base64Encode(Uint8List(16)));

    await expectLater(storageKey.obtain(), throwsA(isA<StorageKeyException>()));
  });

  test('malformed base64 throws StorageKeyException', () async {
    mockMethods((call) async => 'not-base64!!');

    await expectLater(storageKey.obtain(), throwsA(isA<StorageKeyException>()));
  });

  test('a null result throws StorageKeyException', () async {
    mockMethods((call) async => null);

    await expectLater(storageKey.obtain(), throwsA(isA<StorageKeyException>()));
  });

  test('a PlatformException maps to StorageKeyException carrying its code', () async {
    mockMethods(
      (call) async => throw PlatformException(code: 'storage_key_unavailable', message: 'nope'),
    );

    await expectLater(
      storageKey.obtain(),
      throwsA(
        isA<StorageKeyException>()
            .having((e) => e.code, 'code', 'storage_key_unavailable')
            .having((e) => e.message, 'message', 'nope'),
      ),
    );
  });

  test('a missing plugin throws StorageKeyException', () async {
    await expectLater(storageKey.obtain(), throwsA(isA<StorageKeyException>()));
  });
}
