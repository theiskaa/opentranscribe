import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/services/import_merge.dart';

void main() {
  final at = DateTime.utc(2026, 8, 5, 9);
  final staged = File('staged.m4a');

  Entry entry(String id, {String? audio, String? title}) => Entry(
    id: id,
    createdAt: at,
    audioPath: audio,
    duration: const Duration(seconds: 3),
    title: title,
  );

  StagedImportEntry item(String id, {String? audio, String? title}) => StagedImportEntry(
    entry: entry(id, audio: audio, title: title),
    stagedAudio: audio == null ? null : staged,
  );

  test('an identical record whose recording is missing here plans to bring it back', () {
    final item = StagedImportEntry(
      entry: entry('a', audio: 'a.m4a'),
      stagedAudio: File('staged/a.m4a'),
    );
    final plan = planAdoption([item], [entry('a', audio: 'a.m4a')], onDisk: (_) => false);
    expect(plan, const ImportPlan(added: 0, replaced: 0, unchanged: 0, recordings: 1));
    expect(plan.isEmpty, isFalse);
    final present = planAdoption([item], [entry('a', audio: 'a.m4a')], onDisk: (_) => true);
    expect(present, const ImportPlan(added: 0, replaced: 0, unchanged: 1));
  });

  test('an identical record whose file is here moves nothing, though another id owns the name', () {
    final a = entry('a', audio: 'x.m4a');
    final step = adoptStepFor(
      item('a', audio: 'x.m4a'),
      existing: a,
      owners: {'x.m4a': 'b'},
      onDisk: (_) => true,
      stagedExists: (_) => true,
      mint: () => 'minted.m4a',
    );
    expect(step.record, a);
    expect(step.moveAs, isNull);
  });

  group('two records sharing one recording', () {
    final orders = {
      'a stored first': [entry('a', audio: 'x.m4a'), entry('b', audio: 'x.m4a')],
      'b stored first': [entry('b', audio: 'x.m4a'), entry('a', audio: 'x.m4a')],
    };

    for (final MapEntry(key: order, value: stored) in orders.entries) {
      test('with the file missing, it comes back once and neither reads replaced, $order', () {
        final plan = planAdoption(
          [item('a', audio: 'x.m4a'), item('b', audio: 'x.m4a')],
          stored,
          onDisk: (_) => false,
        );
        expect(plan, const ImportPlan(added: 0, replaced: 0, unchanged: 1, recordings: 1));
      });

      test('with the file here and one edited, the edit keeps the shared name, $order', () {
        final plan = planAdoption(
          [item('a', audio: 'x.m4a'), item('b', audio: 'x.m4a', title: 'Edited')],
          stored,
          onDisk: (name) => name == 'x.m4a',
        );
        expect(plan, const ImportPlan(added: 0, replaced: 1, unchanged: 1));
        final step = adoptStepFor(
          item('b', audio: 'x.m4a', title: 'Edited'),
          existing: entry('b', audio: 'x.m4a'),
          owners: audioOwners(stored),
          onDisk: (name) => name == 'x.m4a',
          stagedExists: (_) => true,
          mint: () => 'minted.m4a',
        );
        expect(step.record?.audioPath, 'x.m4a');
        expect(step.moveAs, isNull);
      });
    }
  });

  test('a plan is empty only when it adds, replaces and updates nothing', () {
    expect(const ImportPlan(added: 0, replaced: 0, unchanged: 4).isEmpty, isTrue);
    expect(const ImportPlan(added: 0, replaced: 1, unchanged: 0).isEmpty, isFalse);
    expect(const ImportPlan(added: 0, replaced: 0, unchanged: 4, reflections: 2).isEmpty, isFalse);
    expect(const ImportPlan(added: 0, replaced: 0, unchanged: 4, recordings: 1).isEmpty, isFalse);
  });

  test('a re-import over a stray file reuses the fresh name the entry already got', () {
    expect(
      planAdoption(
        [item('a', audio: 'a.m4a')],
        [entry('a', audio: '${importAudioPrefix}1.m4a')],
        onDisk: (_) => true,
      ),
      const ImportPlan(added: 0, replaced: 0, unchanged: 1),
    );
  });

  test('a minted name stands once the stray that forced it is gone, so a re-import is a no-op', () {
    expect(
      planAdoption(
        [item('a', audio: 'a.m4a')],
        [entry('a', audio: '${importAudioPrefix}1.m4a')],
        onDisk: (name) => name != 'a.m4a',
      ),
      const ImportPlan(added: 0, replaced: 0, unchanged: 1),
    );
  });

  test('an archive into an empty journal adds every record', () {
    expect(
      planAdoption([item('a', audio: 'a.m4a'), item('b')], const []),
      const ImportPlan(added: 2, replaced: 0, unchanged: 0),
    );
  });

  test('an identical record is unchanged and a differing one is replaced', () {
    expect(
      planAdoption(
        [item('a', title: 'same'), item('b', title: 'archive')],
        [entry('a', title: 'same'), entry('b', title: 'local')],
      ),
      const ImportPlan(added: 0, replaced: 1, unchanged: 1),
    );
  });

  test('a record whose audio another entry owns is added under a minted name', () {
    expect(
      planAdoption([item('a', audio: 'x.m4a')], [entry('other', audio: 'x.m4a')]),
      const ImportPlan(added: 1, replaced: 0, unchanged: 0),
    );
  });

  test('a rename an earlier import made is reused, so the record reads unchanged', () {
    expect(
      planAdoption(
        [item('a', audio: 'x.m4a')],
        [entry('other', audio: 'x.m4a'), entry('a', audio: '${importAudioPrefix}1.m4a')],
        onDisk: (_) => true,
      ),
      const ImportPlan(added: 0, replaced: 0, unchanged: 1),
    );
  });

  test('a recording already on disk under its own record is unchanged', () {
    expect(
      planAdoption(
        [item('a', audio: 'a.m4a')],
        [entry('a', audio: 'a.m4a')],
        onDisk: (_) => true,
      ),
      const ImportPlan(added: 0, replaced: 0, unchanged: 1),
    );
  });

  test('a stray file nobody owns is never adopted: the name is minted fresh', () {
    final owners = <String, String>{};
    final step = adoptStepFor(
      item('a', audio: 'a.m4a'),
      existing: null,
      owners: owners,
      onDisk: (name) => name == 'a.m4a',
      stagedExists: (_) => true,
      mint: () => 'fresh.m4a',
    );
    expect(step.moveAs, 'fresh.m4a');
    expect(step.record?.audioPath, 'fresh.m4a');
    expect(owners, {'fresh.m4a': 'a'});
  });

  test('two new records sharing one recording each get a file of their own', () {
    final names = <String>[];
    final owners = <String, String>{};
    for (final id in ['a', 'b']) {
      final step = adoptStepFor(
        item(id, audio: 'x.m4a'),
        existing: null,
        owners: owners,
        onDisk: (_) => false,
        stagedExists: (_) => true,
        mint: () => 'minted-$id.m4a',
      );
      names.add(step.moveAs!);
    }
    expect(names, ['x.m4a', 'minted-b.m4a']);
  });

  test('a staged recording that is gone lands a new record transcript-only', () {
    final step = adoptStepFor(
      item('a', audio: 'a.m4a'),
      existing: null,
      owners: {},
      onDisk: (_) => false,
      stagedExists: (_) => false,
      mint: () => 'fresh.m4a',
    );
    expect(step.moveAs, isNull);
    expect(step.record?.audioPath, isNull);
  });

  test('a staged recording that is gone leaves a stored record as it was', () {
    expect(
      planAdoption(
        [item('a', audio: 'a.m4a', title: 'archive')],
        [entry('a', audio: 'local.m4a', title: 'local')],
        stagedExists: (_) => false,
      ),
      const ImportPlan(added: 0, replaced: 0, unchanged: 1),
    );
  });

  test('a file an earlier pass landed is reused under its landed name with nothing moved', () {
    final step = adoptStepFor(
      item('a', audio: 'x.m4a'),
      existing: null,
      owners: {'x.m4a': 'other'},
      onDisk: (name) => name == 'landed.m4a',
      stagedExists: (_) => false,
      mint: () => 'fresh.m4a',
      landed: 'landed.m4a',
    );
    expect(step.moveAs, isNull);
    expect(step.record?.audioPath, 'landed.m4a');
  });

  test('a landed file another entry took over leaves a stored record untouched', () {
    final step = adoptStepFor(
      item('a', audio: 'x.m4a'),
      existing: entry('a', audio: 'local.m4a'),
      owners: {'landed.m4a': 'orphan'},
      onDisk: (_) => true,
      stagedExists: (_) => false,
      mint: () => 'fresh.m4a',
      landed: 'landed.m4a',
    );
    expect(step.record, isNull);
    expect(step.moveAs, isNull);
  });

  test('a recording a replacement frees can be claimed by a later record', () {
    expect(
      planAdoption(
        [item('a', audio: 'z.m4a'), item('b', audio: 'y.m4a')],
        [entry('a', audio: 'y.m4a')],
        onDisk: (name) => name == 'y.m4a',
      ),
      const ImportPlan(added: 1, replaced: 1, unchanged: 0),
    );
  });

  test('the old file a replacement leaves unreferenced is the one released', () {
    expect(
      releasedAudio(entry('a', audio: 'y.m4a'), entry('a', audio: 'z.m4a'), const []),
      'y.m4a',
    );
    expect(
      releasedAudio(entry('a', audio: 'y.m4a'), entry('a', audio: 'z.m4a'), [
        entry('b', audio: 'y.m4a'),
      ]),
      isNull,
    );
    expect(releasedAudio(entry('a', audio: 'y.m4a'), entry('a'), const []), isNull);
  });

  test(
    'only a step that moved a file in counts a recording back, never one an earlier pass landed',
    () {
      final ledger = AdoptLedger()
        ..land(0, 'a.m4a')
        ..settle(0, existing: entry('a', audio: 'a.m4a'), saved: null)
        ..settle(1, existing: entry('b', audio: 'b.m4a'), saved: null, moved: true);
      expect(ledger.result.recordingsBroughtBack, 1);
    },
  );

  test('the ledger counts the adds and replaces it settled, and knows what never settled', () {
    final ledger = AdoptLedger()
      ..land(0, 'a.m4a')
      ..land(1, 'b.m4a')
      ..settle(0, existing: null, saved: entry('a', audio: 'a.m4a'))
      ..settle(
        2,
        existing: entry('c'),
        saved: entry('c', title: 'new'),
      )
      ..settle(3, existing: entry('d'), saved: null);
    expect(ledger.result, const ImportSummary(entriesAdded: 1, entriesReplaced: 1));
    expect(ledger.unsettledLandings, ['b.m4a']);
    expect(ledger.isSettled(1), isFalse);
    expect(ledger.landedAt(1), 'b.m4a');
  });
}
