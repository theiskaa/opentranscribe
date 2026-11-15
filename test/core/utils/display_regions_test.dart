import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/models/display_signal.dart';

import '../../support/fake_display_channels.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final channels = <FakeDisplayChannels>[];
  FakeDisplayChannels fake({
    Object? current,
    List<Object?> pushes = const [],
    bool broken = false,
  }) {
    final created = FakeDisplayChannels(current: current, pushes: pushes, broken: broken);
    channels.add(created);
    return created;
  }

  tearDown(() {
    for (final c in channels) {
      c.dispose();
    }
    channels.clear();
  });

  group('the monitor', () {
    test('reads as unsupported before it has heard anything', () {
      final monitor = fake().monitor();

      expect(monitor.current, DisplaySignal.unsupported);
    });

    test('caches the pushed signal', () async {
      final monitor = fake(pushes: [DisplayWire.cover]).monitor()..start();
      await Future<void>.delayed(Duration.zero);

      expect(monitor.current, DisplayWire.decode(DisplayWire.cover));

      await monitor.dispose();
    });

    test('takes the probe answer when the opening push was lost', () async {
      final monitor = fake(current: DisplayWire.flatWide).monitor()..start();
      await Future<void>.delayed(Duration.zero);

      expect(monitor.current, DisplayWire.decode(DisplayWire.flatWide));

      await monitor.dispose();
    });

    test('keeps a pushed signal over the staler probe answer', () async {
      final monitor = fake(current: DisplayWire.cover, pushes: [DisplayWire.bookWide]).monitor()
        ..start();
      await Future<void>.delayed(Duration.zero);

      expect(monitor.current, DisplayWire.decode(DisplayWire.bookWide));

      await monitor.dispose();
    });

    test('announces each distinct signal once, in order', () async {
      final channel = fake(pushes: [DisplayWire.cover]);
      final monitor = channel.monitor();
      final seen = <DisplaySignal>[];
      monitor.changes.listen(seen.add);
      monitor.start();
      await Future<void>.delayed(Duration.zero);
      channel
        ..push(DisplayWire.cover)
        ..push(DisplayWire.bookWide)
        ..push(DisplayWire.flatWide);
      await Future<void>.delayed(Duration.zero);

      expect(seen, [
        DisplayWire.decode(DisplayWire.cover),
        DisplayWire.decode(DisplayWire.bookWide),
        DisplayWire.decode(DisplayWire.flatWide),
      ]);

      await monitor.dispose();
    });

    test('a broken channel reads as unsupported', () async {
      final monitor = fake(broken: true).monitor()..start();
      await Future<void>.delayed(Duration.zero);

      expect(monitor.current, DisplaySignal.unsupported);

      await monitor.dispose();
    });

    test('a stream error after a good signal falls back to unsupported', () async {
      final channel = fake(pushes: [DisplayWire.bookWide]);
      final monitor = channel.monitor()..start();
      await Future<void>.delayed(Duration.zero);
      channel.fail();
      await Future<void>.delayed(Duration.zero);

      expect(monitor.current, DisplaySignal.unsupported);

      await monitor.dispose();
    });

    test('a malformed push falls back to unsupported rather than a guess', () async {
      final channel = fake(pushes: [DisplayWire.bookWide]);
      final monitor = channel.monitor()..start();
      await Future<void>.delayed(Duration.zero);
      channel.push({...DisplayWire.bookWide, 'width': 'wide'});
      await Future<void>.delayed(Duration.zero);

      expect(monitor.current, DisplaySignal.unsupported);

      await monitor.dispose();
    });

    test('starting twice listens once and probes once', () async {
      final channel = fake(pushes: [DisplayWire.cover]);
      final monitor = channel.monitor()
        ..start()
        ..start();
      await Future<void>.delayed(Duration.zero);

      expect(channel.listens, 1);
      expect(channel.probes, 1);

      await monitor.dispose();
    });
  });
}
