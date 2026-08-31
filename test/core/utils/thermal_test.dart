import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/utils/thermal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const methods = MethodChannel('opentranscribe/thermal');
  const events = EventChannel('opentranscribe/thermal/events');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(methods, null);
    messenger.setMockStreamHandler(events, null);
  });

  test('pressure folds serious and critical to true, everything else to false', () async {
    for (final (state, pressured) in [
      ('nominal', false),
      ('fair', false),
      ('serious', true),
      ('critical', true),
    ]) {
      messenger.setMockMethodCallHandler(methods, (call) async => state);
      messenger.setMockStreamHandler(
        events,
        MockStreamHandler.inline(onListen: (arguments, sink) {}),
      );
      final monitor = ThermalMonitor()..start();
      await Future<void>.delayed(Duration.zero);
      expect(monitor.underPressure, pressured);
      await monitor.dispose();
    }
  });

  test('a pushed change updates the cached answer without a probe', () async {
    messenger.setMockMethodCallHandler(methods, (call) async => 'nominal');
    messenger.setMockStreamHandler(
      events,
      MockStreamHandler.inline(
        onListen: (arguments, sink) {
          sink.success('serious');
        },
      ),
    );
    final monitor = ThermalMonitor()..start();
    await Future<void>.delayed(Duration.zero);

    expect(monitor.underPressure, isTrue);

    await monitor.dispose();
  });

  test('a broken channel reads as no pressure', () async {
    messenger.setMockMethodCallHandler(methods, (call) async {
      throw PlatformException(code: 'gone');
    });
    messenger.setMockStreamHandler(
      events,
      MockStreamHandler.inline(
        onListen: (arguments, sink) {
          sink.error(code: 'gone');
        },
      ),
    );
    final monitor = ThermalMonitor()..start();
    await Future<void>.delayed(Duration.zero);

    expect(monitor.underPressure, isFalse);

    await monitor.dispose();
  });

  test('start is idempotent and keeps one subscription', () async {
    var listens = 0;
    messenger.setMockMethodCallHandler(methods, (call) async => 'nominal');
    messenger.setMockStreamHandler(
      events,
      MockStreamHandler.inline(
        onListen: (arguments, sink) {
          listens++;
          sink.success('serious');
        },
      ),
    );
    final monitor = ThermalMonitor()
      ..start()
      ..start();
    await Future<void>.delayed(Duration.zero);

    expect(listens, 1);
    expect(monitor.underPressure, isTrue);

    await monitor.dispose();
  });
}
