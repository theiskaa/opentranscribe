import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/app/engine_registry.dart';
import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/models/engine_descriptor.dart';
import 'package:opentranscribe/core/services/engine_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transcriber/testing.dart';

void main() {
  const key = 'test-encryption-key-0123456789ab';
  late LocalService storage;
  late EngineSettings settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalService();
    await storage.init(legacyKey: key);
    settings = EngineSettings(storage: storage);
  });

  EngineEntry entry(String id, {required bool available}) => EngineEntry(
    descriptor: EngineDescriptor(engineId: id, displayName: id, logo: const IconData(0x21)),
    engine: FakeBatchEngine(),
    available: available,
    unavailability: available ? null : EngineUnavailability.needsNewerDevice,
  );

  test('auto resolves to the first available entry', () {
    final registry = [entry('a', available: false), entry('b', available: true)];

    expect(settings.resolveActive(registry).descriptor.engineId, 'b');
  });

  test('a stored available engine beats registry order', () async {
    await settings.setEngineId('c');
    final registry = [entry('b', available: true), entry('c', available: true)];

    expect(settings.resolveActive(registry).descriptor.engineId, 'c');
  });

  test('a stored engine this device cannot run reads as auto', () async {
    await settings.setEngineId('a');
    final registry = [entry('a', available: false), entry('b', available: true)];

    expect(settings.resolveActive(registry).descriptor.engineId, 'b');
  });

  test('a stored id nothing ships reads as auto', () async {
    await settings.setEngineId('gone');
    final registry = [entry('a', available: true), entry('b', available: true)];

    expect(settings.resolveActive(registry).descriptor.engineId, 'a');
  });

  test('an all-unavailable registry still answers its first entry', () {
    final registry = [entry('a', available: false), entry('b', available: false)];

    expect(settings.resolveActive(registry).descriptor.engineId, 'a');
  });

  test('the choice survives a reload', () async {
    await settings.setEngineId('b');

    expect(EngineSettings(storage: storage).engineId, 'b');
  });
}
