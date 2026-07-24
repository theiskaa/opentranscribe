import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/services/entry_store.dart';
import 'package:opentranscribe/core/services/transcription_service.dart';
import 'package:opentranscribe/core/state/home_cubit.dart';
import 'package:opentranscribe/core/transcribe/fake_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_audio_recorder.dart';

void main() {
  // Local times, so grouping assertions hold in any timezone the test runs in.
  Entry entryAt(DateTime local, {String id = ''}) => Entry(
    id: id.isEmpty ? local.toIso8601String() : id,
    createdAt: local,
    audioPath: 'a.m4a',
    duration: const Duration(seconds: 5),
  );

  group('groupByLocalDay', () {
    test('groups by local day, sections newest first, in-day order preserved', () {
      final entries = [
        entryAt(DateTime(2026, 7, 23, 18), id: 'c-late'),
        entryAt(DateTime(2026, 7, 23, 9), id: 'c-early'),
        entryAt(DateTime(2026, 7, 19, 12), id: 'b'),
        entryAt(DateTime(2025, 12, 31, 23), id: 'a'),
      ];

      final sections = groupByLocalDay(entries);

      expect(sections.map((s) => s.day), [
        DateTime(2026, 7, 23),
        DateTime(2026, 7, 19),
        DateTime(2025, 12, 31),
      ]);
      expect(sections.first.entries.map((e) => e.id), ['c-late', 'c-early']);
    });

    test('days without entries have no section', () {
      final sections = groupByLocalDay([
        entryAt(DateTime(2026, 7, 23)),
        entryAt(DateTime(2026, 7, 20)),
      ]);

      expect(sections, hasLength(2));
    });

    test('an entry just before local midnight stays on its local day', () {
      // Stored as UTC (the Entry constructor normalizes); grouping must come
      // back to the local calendar day it was recorded on.
      final lateEvening = DateTime(2026, 7, 22, 23, 55);
      final sections = groupByLocalDay([entryAt(lateEvening)]);

      expect(sections.single.day, DateTime(2026, 7, 22));
    });
  });

  test('daysWithEntries matches the section days', () {
    final entries = [
      entryAt(DateTime(2026, 7, 23, 8), id: 'x'),
      entryAt(DateTime(2026, 7, 23, 9), id: 'y'),
      entryAt(DateTime(2026, 6, 5), id: 'z'),
    ];

    expect(daysWithEntries(entries), {DateTime(2026, 7, 23), DateTime(2026, 6, 5)});
  });

  group('HomeCubit', () {
    late TranscriptionService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final storage = LocalService();
      await storage.init(encryptionKey: 'test-encryption-key-0123456789ab');
      service = TranscriptionService(
        recorder: FakeAudioRecorder(),
        engine: FakeBatchEngine(),
        store: EntryStore(storage),
      );
    });

    tearDown(() => service.dispose());

    test('firstEntryDay is the earliest local day, null when empty', () {
      expect(earliestEntryDay(const []), isNull);
      expect(
        earliestEntryDay([
          entryAt(DateTime(2026, 7, 23), id: 'later'),
          entryAt(DateTime(2026, 7, 20, 22), id: 'earliest'),
        ]),
        DateTime(2026, 7, 20),
      );
    });

    test('sections cover every day with entries, newest first', () async {
      final cubit = HomeCubit(service: service);
      cubit.emit(
        HomeState(entries: [entryAt(DateTime(2026, 7, 20)), entryAt(DateTime(2026, 7, 23))]),
      );

      expect(cubit.state.sections.map((s) => s.day), [
        DateTime(2026, 7, 23),
        DateTime(2026, 7, 20),
      ]);

      await cubit.close();
    });

    test('load pulls fresh entries', () async {
      final cubit = HomeCubit(service: service);

      await service.startRecording();
      await service.stopRecording();
      cubit.load();

      expect(cubit.state.entries, hasLength(1));

      await cubit.close();
    });

    test('an auto-finalized entry refreshes the list', () async {
      final rec = FakeAudioRecorder();
      SharedPreferences.setMockInitialValues({});
      final storage = LocalService();
      await storage.init(encryptionKey: 'test-encryption-key-0123456789ab');
      final svc = TranscriptionService(
        recorder: rec,
        engine: FakeBatchEngine(),
        store: EntryStore(storage),
      );
      final cubit = HomeCubit(service: svc);

      await svc.startRecording();
      rec.interrupt();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(cubit.state.entries, hasLength(1));

      await cubit.close();
      await svc.dispose();
    });
  });
}
