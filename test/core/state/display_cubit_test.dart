import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/models/display_signal.dart';
import 'package:opentranscribe/core/state/display_cubit.dart';
import 'package:opentranscribe/core/theming/app_dimens.dart';

import '../../support/display_fixtures.dart';
import '../../support/fake_display_channels.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeDisplayChannels channels;

  final poses = [
    DisplayWire.cover,
    DisplayWire.bookWide,
    DisplayWire.flatWide,
    DisplayWire.flatTall,
    DisplayWire.cover,
  ];
  final widerCover = {
    ...DisplayWire.cover,
    'width': 470.0,
    'insets': DisplayWire.insets(0, 0, 34, 80),
  };

  setUp(() => channels = FakeDisplayChannels());
  tearDown(() => channels.dispose());

  test("starts from the monitor's current signal and the closed width token", () async {
    final cubit = DisplayCubit(monitor: channels.monitor());

    expect(cubit.state.signal, DisplaySignal.unsupported);
    expect(cubit.state.closedContentWidth, AppDuo.closedContentWidth);

    await cubit.close();
  });

  test('a cubit built after the first push starts from it', () async {
    channels.pushes = [DisplayWire.flatWide];
    final monitor = channels.monitor()..start();
    await Future<void>.delayed(Duration.zero);
    final cubit = DisplayCubit(monitor: monitor);

    expect(cubit.state.signal, DisplayWire.decode(DisplayWire.flatWide));

    await cubit.close();
    await monitor.dispose();
  });

  test('follows every pose the device moves through', () async {
    final monitor = channels.monitor();
    final cubit = DisplayCubit(monitor: monitor);
    monitor.start();
    await Future<void>.delayed(Duration.zero);
    final seen = <DisplaySignal>[];
    final sub = cubit.stream.listen((state) => seen.add(state.signal));

    poses.forEach(channels.push);
    await Future<void>.delayed(Duration.zero);

    expect(seen, poses.map(DisplayWire.decode));

    await sub.cancel();
    await cubit.close();
    await monitor.dispose();
  });

  test('the closed width becomes the last cover window seen and outlasts the unfold', () async {
    final monitor = channels.monitor();
    final cubit = DisplayCubit(monitor: monitor);
    monitor.start();
    await Future<void>.delayed(Duration.zero);

    channels.push(widerCover);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.closedContentWidth, 390);

    channels.push(DisplayWire.bookWide);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.signal.horizontal, SizeClass.regular);
    expect(cubit.state.closedContentWidth, 390);

    await cubit.close();
    await monitor.dispose();
  });

  test('only the closed device full screen counts as the closed window', () {
    double? widthOf(Map<String, Object?> wire) =>
        DisplayCubit.closedContentWidthOf(DisplayWire.decode(wire));

    expect(widthOf(DisplayWire.cover), 382);
    expect(widthOf(DisplayWire.iphone), isNull);
    expect(widthOf(DisplayWire.flatWide), isNull);
    expect(widthOf(DisplayWire.flatTall), isNull);
    expect(widthOf(DisplayWire.unsupported), isNull);
    expect(widthOf({...DisplayWire.cover, 'insets': DisplayWire.insets(0, 0, 34, 0)}), isNull);
  });

  test('a cover reading far from the device is pulled back into the sane band', () {
    double? widthOf(double width) => DisplayCubit.closedContentWidthOf(
      DisplayWire.decode({...DisplayWire.cover, 'width': width}),
    );

    expect(widthOf(1000), AppDuo.closedContentWidthMax);
    expect(widthOf(200), AppDuo.closedContentWidthMin);
  });

  test('Split View halves and Slide Over on the open device leave the memory alone', () async {
    final monitor = channels.monitor();
    final cubit = DisplayCubit(monitor: monitor);
    monitor.start();
    await Future<void>.delayed(Duration.zero);

    channels.push(widerCover);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.closedContentWidth, 390);

    for (final window in [
      DisplayWire.signal(
        width: splitHalfWidth,
        height: 669,
        horizontal: 'compact',
        insets: DisplayWire.insets(0, 0, 34, 84),
        fullScreen: false,
        barSide: 'right',
        regions: [DisplayWire.region('division', 0, 0, 20, 669, active: false)],
      ),
      DisplayWire.signal(
        width: splitHalfWidth,
        height: 669,
        horizontal: 'compact',
        insets: DisplayWire.insets(0, 0, 34, 0),
        fullScreen: false,
        regions: [DisplayWire.region('division', 455, 0, 20, 669, active: false)],
      ),
      DisplayWire.signal(
        width: 320,
        height: 669,
        horizontal: 'compact',
        insets: DisplayWire.insets(0, 0, 34, 84),
        fullScreen: false,
        barSide: 'right',
      ),
    ]) {
      channels.push(window);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.signal, DisplayWire.decode(window));
      expect(cubit.state.closedContentWidth, 390);
    }

    await cubit.close();
    await monitor.dispose();
  });

  test('a full-screen compact window holding a division is not the closed device', () {
    final folded = {
      ...DisplayWire.cover,
      'regions': [DisplayWire.region('division', 200, 0, 40, 678, active: false)],
    };

    expect(DisplayCubit.closedContentWidthOf(DisplayWire.decode(folded)), isNull);
  });

  test('a broken monitor leaves the cubit unsupported', () async {
    channels.broken = true;
    final monitor = channels.monitor();
    final cubit = DisplayCubit(monitor: monitor);
    monitor.start();
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.signal, DisplaySignal.unsupported);

    await cubit.close();
    await monitor.dispose();
  });

  test('a signal landing after close is dropped quietly', () async {
    final monitor = channels.monitor();
    final cubit = DisplayCubit(monitor: monitor);
    monitor.start();
    await Future<void>.delayed(Duration.zero);
    await cubit.close();

    channels.push(DisplayWire.cover);
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.signal, DisplaySignal.unsupported);

    await monitor.dispose();
  });
}
