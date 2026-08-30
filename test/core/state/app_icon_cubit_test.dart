import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/app/app_icon.dart';
import 'package:opentranscribe/core/models/app_icon_descriptor.dart';
import 'package:opentranscribe/core/state/app_icon_cubit.dart';

import '../../support/fake_app_icon_store.dart';

void main() {
  final options = [
    AppIconDescriptor(id: 'default', iconName: null, preview: 'd.png', name: (_) => 'Default'),
    AppIconDescriptor(
      id: 'signal',
      iconName: 'AppIcon-Signal',
      preview: 's.png',
      name: (_) => 'Signal',
    ),
  ];
  final clubOptions = [
    AppIconDescriptor(id: 'default', iconName: null, preview: 'd.png', name: (_) => 'Default'),
    AppIconDescriptor(
      id: 'signal',
      iconName: 'AppIcon-Signal',
      preview: 's.png',
      name: (_) => 'Signal',
      club: true,
    ),
  ];
  late FakeAppIconStore store;
  late StreamController<void> tier;
  var member = false;

  setUp(() {
    store = FakeAppIconStore();
    tier = StreamController<void>.broadcast();
    member = false;
  });

  tearDown(() => tier.close());

  AppIconCubit cubit() => AppIconCubit(store: store, options: options);

  AppIconCubit clubCubit() => AppIconCubit(
    store: store,
    options: clubOptions,
    isSupporter: () => member,
    tierChanges: tier.stream,
  );

  test('the icon is unknown until the OS answers, then marked as it reads', () async {
    store.currentAnswer = 'AppIcon-Signal';
    final c = cubit();
    expect(c.state.currentId, isNull);
    await c.load();
    expect(c.state.currentId, 'signal');
  });

  test('an alternate name this build no longer ships reads as the primary icon', () async {
    store.currentAnswer = 'AppIcon-Gone';
    final c = cubit();
    await c.load();
    expect(c.state.currentId, 'default');
  });

  test('a store that cannot read the icon leaves it unknown, so a tap still sends', () async {
    store.currentError = const AppIconStoreException('no');
    final c = cubit();
    await c.load();
    expect(c.state.currentId, isNull);
    expect(await c.pick('default'), AppIconPickOutcome.switched);
    expect(store.sets, [null]);
  });

  test('picking an alternate then the primary sends its name then null', () async {
    final c = cubit();
    await c.load();
    expect(await c.pick('signal'), AppIconPickOutcome.switched);
    expect(c.state.currentId, 'signal');
    expect(await c.pick('default'), AppIconPickOutcome.switched);
    expect(store.sets, ['AppIcon-Signal', null]);
  });

  test('picking the icon already shown sends nothing', () async {
    store.currentAnswer = 'AppIcon-Signal';
    final c = cubit();
    await c.load();
    expect(await c.pick('signal'), AppIconPickOutcome.unchanged);
    expect(store.sets, isEmpty);
  });

  test('a refused switch reports failed and keeps the previous mark', () async {
    store.setError = const AppIconStoreException('no');
    final c = cubit();
    await c.load();
    expect(await c.pick('signal'), AppIconPickOutcome.failed);
    expect(c.state.currentId, 'default');
    expect(c.state.busy, isFalse);
  });

  test('a tap while a switch is in flight is dropped', () async {
    final gate = Completer<void>();
    store.setGate = gate.future;
    final c = cubit();
    await c.load();
    final first = c.pick('signal');
    expect(await c.pick('default'), AppIconPickOutcome.unchanged);
    gate.complete();
    expect(await first, AppIconPickOutcome.switched);
    expect(store.sets, ['AppIcon-Signal']);
  });

  test('a pick that lands before a slow read wins over the read', () async {
    final gate = Completer<void>();
    store.currentGate = gate.future;
    final c = cubit();
    final read = c.load();
    expect(await c.pick('signal'), AppIconPickOutcome.switched);
    gate.complete();
    await read;
    expect(c.state.currentId, 'signal');
  });

  test('a cubit closed mid-switch emits nothing after the switch lands', () async {
    final gate = Completer<void>();
    store.setGate = gate.future;
    final c = cubit();
    await c.load();
    final pending = c.pick('signal');
    await c.close();
    gate.complete();
    expect(await pending, AppIconPickOutcome.switched);
    expect(c.state.busy, isTrue);
  });

  test('a club icon is refused without a membership, and nothing reaches the OS', () async {
    final c = clubCubit();
    await c.load();
    expect(await c.pick('signal'), AppIconPickOutcome.locked);
    expect(store.sets, isEmpty);
    expect(c.state.currentId, 'default');
  });

  test('the primary icon is never gated', () async {
    store.currentAnswer = 'AppIcon-Signal';
    final c = clubCubit();
    await c.load();
    expect(await c.pick('default'), AppIconPickOutcome.switched);
    expect(store.sets, [null]);
  });

  test('a membership landing on the tier stream opens the club icons', () async {
    final c = clubCubit();
    await c.load();
    expect(await c.pick('signal'), AppIconPickOutcome.locked);
    member = true;
    tier.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(c.state.member, isTrue);
    expect(await c.pick('signal'), AppIconPickOutcome.switched);
    expect(store.sets, ['AppIcon-Signal']);
  });

  test('a lapsed membership leaves the club icon the OS already wears', () async {
    store.currentAnswer = 'AppIcon-Signal';
    member = true;
    final c = clubCubit();
    await c.load();
    member = false;
    tier.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(c.state.currentId, 'signal');
    expect(store.sets, isEmpty);
  });
}
