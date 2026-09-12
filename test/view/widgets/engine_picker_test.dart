import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/models/engine_descriptor.dart';
import 'package:opentranscribe/core/state/engines_cubit.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/widgets/engine_picker.dart';

import '../../support/engine_fixtures.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  EngineRowState row(
    String id, {
    bool active = false,
    bool available = true,
    EngineUnavailability? unavailability,
  }) => EngineRowState(
    descriptor: engineDescriptor(id, displayName: id.toUpperCase(), blurb: (_) => 'what $id is'),
    available: available,
    isActive: active,
    unavailability: unavailability,
  );

  group('shownRow', () {
    test('the engine a pick is waiting on outranks the active one', () {
      final rows = [row('a', active: true), row('b')];

      expect(shownRow(rows, pending: 'b').descriptor.engineId, 'b');
    });

    test('the active engine shows while nothing is pending', () {
      final rows = [row('a'), row('b', active: true)];

      expect(shownRow(rows).descriptor.engineId, 'b');
    });

    test('a pending engine the rows do not carry falls back to the active one', () {
      final rows = [row('a', active: true), row('b')];

      expect(shownRow(rows, pending: 'gone').descriptor.engineId, 'a');
    });

    test('rows that mark nothing active answer their first', () {
      final rows = [row('a'), row('b')];

      expect(shownRow(rows).descriptor.engineId, 'a');
    });
  });

  group('engineNote', () {
    test('an engine that runs here says what it is', () {
      expect(engineNote(l10n, row('a')), 'what a is');
    });

    test('an engine the device is too old for says so instead', () {
      final old = row('a', available: false, unavailability: EngineUnavailability.needsNewerDevice);

      expect(engineNote(l10n, old), l10n.engineUnavailableNote);
    });

    test('an engine whose storage went missing says that instead', () {
      final noStorage = row(
        'a',
        available: false,
        unavailability: EngineUnavailability.storageUnavailable,
      );

      expect(engineNote(l10n, noStorage), l10n.engineStorageUnavailableNote);
    });
  });

  group('refusalMessage', () {
    test('a take in flight and a bulk run word apart', () {
      final busy = refusalMessage(l10n, EnginePickOutcome.busy);
      final running = refusalMessage(l10n, EnginePickOutcome.retranscribing);

      expect(busy?.title, l10n.engineBusyTitle);
      expect(running?.title, l10n.engineRetranscribingTitle);
      expect(busy?.title, isNot(running?.title));
    });

    test('a pick that took, or that changed nothing, has nothing to say', () {
      expect(refusalMessage(l10n, EnginePickOutcome.switched), isNull);
      expect(refusalMessage(l10n, EnginePickOutcome.unchanged), isNull);
    });

    test('an unavailable engine is told its own story, not a refusal', () {
      expect(refusalMessage(l10n, EnginePickOutcome.unavailable), isNull);
    });
  });
}
