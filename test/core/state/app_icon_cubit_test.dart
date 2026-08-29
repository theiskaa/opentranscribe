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

  AppIconCubit build() {
    final cubit = AppIconCubit(
      store: store,
      options: options,
      isSupporter: () => member,
      tierChanges: tier.stream,
    );
    addTearDown(cubit.close);
    return cubit;
  }

  test('opens on the primary icon and reads what the OS shows on load', () async {
    store.currentAnswer = 'AppIcon-Signal';
    final cubit = build();
    expect(cubit.state.currentId, 'default');

    await cubit.load();
    expect(cubit.state.currentId, 'signal');
  });

  test('an icon name the build does not ship reads as the primary icon', () async {
    store.currentAnswer = 'AppIcon-Gone';
    final cubit = build();
    await cubit.load();
    expect(cubit.state.currentId, 'default');
  });

  test('a non-member cannot pick a club icon and the OS is never asked', () async {
    final cubit = build();
    expect(await cubit.pick('signal'), AppIconPickOutcome.locked);
    expect(store.sets, isEmpty);
  });

  test('a member picks a club icon and the primary icon resets to null', () async {
    member = true;
    final cubit = build();
    expect(await cubit.pick('signal'), AppIconPickOutcome.switched);
    expect(cubit.state.currentId, 'signal');
    expect(await cubit.pick('default'), AppIconPickOutcome.switched);
    expect(store.sets, ['AppIcon-Signal', null]);
  });

  test('a refused change answers failed and keeps the current icon', () async {
    member = true;
    store.setError = const AppIconStoreException('no');
    final cubit = build();
    expect(await cubit.pick('signal'), AppIconPickOutcome.failed);
    expect(cubit.state.currentId, 'default');
    expect(cubit.state.busy, isFalse);
  });

  test('a tap while a change is in flight is dropped and the OS is asked once', () async {
    member = true;
    final gate = Completer<void>();
    store.setGate = gate.future;
    final cubit = build();
    final first = cubit.pick('signal');
    expect(await cubit.pick('default'), AppIconPickOutcome.unchanged);
    gate.complete();
    expect(await first, AppIconPickOutcome.switched);
    expect(store.sets, ['AppIcon-Signal']);
  });

  test('a store that cannot read the icon leaves the primary marked', () async {
    store.currentError = const AppIconStoreException('no');
    final cubit = build();
    await cubit.load();
    expect(cubit.state.currentId, 'default');
  });

  test('a lapsed membership leaves a club icon where it is', () async {
    member = true;
    final cubit = build();
    await cubit.pick('signal');
    member = false;
    tier.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.member, isFalse);
    expect(cubit.state.currentId, 'signal');
    expect(await cubit.pick('signal'), AppIconPickOutcome.locked);
  });

  test('picking the current icon changes nothing', () async {
    final cubit = build();
    expect(await cubit.pick('default'), AppIconPickOutcome.unchanged);
    expect(store.sets, isEmpty);
  });

  test('a tier change re-reads membership', () async {
    final cubit = build();
    member = true;
    tier.add(null);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.member, isTrue);
  });
}
