import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/export/archive_codec.dart';
import 'package:opentranscribe/core/services/export_service.dart';
import 'package:opentranscribe/core/services/import_merge.dart';
import 'package:opentranscribe/core/services/import_service.dart';
import 'package:opentranscribe/core/state/backup_cubit.dart';
import 'package:opentranscribe/view/layouts/settings/components/backup_rules.dart';

void main() {
  JournalMeasure measure({int entries = 212, int recordings = 188}) =>
      JournalMeasure(entries: entries, recordings: recordings, approxBytes: 1);

  const sealed = ImportProbe(kind: ArchiveKind.sealed, fileName: 'j.otarchive', sizeBytes: 9);
  const plain = ImportProbe(kind: ArchiveKind.plainZip, fileName: 'j.zip', sizeBytes: 9);
  const plan = ImportPlan(added: 12, replaced: 3, unchanged: 200);
  const nothing = ImportPlan(added: 0, replaced: 0, unchanged: 215);
  const summary = ImportSummary(entriesAdded: 12, entriesReplaced: 3);

  const underWay = <RestoreFlow>[
    RestorePicking(),
    RestoreProbed(sealed),
    RestoreChecking(plain),
    RestorePlanned(plain, plan),
    RestoreRunning(plain, plan, progress: 0.4),
    RestorePartial(plain, plan, summary),
  ];
  const atRest = <RestoreFlow>[
    RestoreIdle(),
    RestoreDone(plain, summary),
    RestoreFailed(RestoreFailure.damaged),
  ];

  group('notes from results', () {
    test('a cancelled backup or export leaves no note to tell', () {
      expect(archiveNoteOf(BackupActionResult.cancelled, sealed: true), isNull);
      expect(exportNoteOf('md', BackupActionResult.cancelled), isNull);
    });

    test('a shared or failed one leaves a note holding what happened, and where', () {
      final archive = archiveNoteOf(BackupActionResult.shared, sealed: true)! as BackupArchiveNote;
      expect(archive.result, BackupActionResult.shared);
      expect(archive.sealed, isTrue);
      final export = exportNoteOf('md', BackupActionResult.failed)! as BackupExportNote;
      expect(export.exporterId, 'md');
      expect(export.result, BackupActionResult.failed);
    });
  });

  group('noteAfterSealFlip', () {
    test("flipping encryption clears the card's outcome but keeps an export's on its row", () {
      expect(noteAfterSealFlip(archiveNoteOf(BackupActionResult.shared, sealed: true)), isNull);
      final export = exportNoteOf('md', BackupActionResult.shared);
      expect(noteAfterSealFlip(export), export);
      expect(noteAfterSealFlip(null), isNull);
    });
  });

  group('leadingCapsule', () {
    Capsule lead(
      BackupState state, {
      bool asking = false,
      bool ready = false,
      bool unlockReady = false,
    }) => leadingCapsule(state, asking: asking, passphraseReady: ready, unlockReady: unlockReady);

    test('encryption on asks for the passphrase before anything runs', () {
      expect(lead(BackupState(measure: measure())), (action: CardAction.askPassphrase, live: true));
    });

    test('encryption off starts the backup at once', () {
      expect(lead(BackupState(measure: measure(), seal: false)), (
        action: CardAction.startBackup,
        live: true,
      ));
    });

    test('with the fields open it submits, live only for an acceptable pair', () {
      final state = BackupState(measure: measure());
      expect(lead(state, asking: true), (action: CardAction.submitBackup, live: false));
      expect(lead(state, asking: true, ready: true), (action: CardAction.submitBackup, live: true));
    });

    test('an empty journal has nothing to back up, while an unmeasured one may start', () {
      expect(lead(BackupState(measure: measure(entries: 0))).live, isFalse);
      expect(lead(const BackupState(seal: false)), (action: CardAction.startBackup, live: true));
    });

    test('an export running leaves Back up disabled, and a backup running makes it a bar', () {
      expect(lead(BackupState(measure: measure(), busy: BackupBusy.exporting)).live, isFalse);
      expect(lead(BackupState(measure: measure(), busy: BackupBusy.archiving)), (
        action: CardAction.none,
        live: false,
      ));
    });

    test('a held restore result does not stand in the way of a backup', () {
      for (final flow in atRest) {
        expect(lead(BackupState(measure: measure(), seal: false, restore: flow)), (
          action: CardAction.startBackup,
          live: true,
        ), reason: '$flow');
      }
    });

    test('a sealed file unlocks from it, live once something is typed', () {
      const state = BackupState(restore: RestoreProbed(sealed, attempt: 1));
      expect(lead(state), (action: CardAction.unlockRestore, live: false));
      expect(lead(state, unlockReady: true), (action: CardAction.unlockRestore, live: true));
    });

    test('a plan and a partial restore both adopt from it', () {
      for (final flow in const <RestoreFlow>[
        RestorePlanned(plain, plan),
        RestorePartial(plain, plan, summary),
      ]) {
        expect(lead(BackupState(restore: flow)), (
          action: CardAction.adoptRestore,
          live: true,
        ), reason: '$flow');
      }
    });

    test('a plan that only updates reflections still adopts from it', () {
      const reflectionsOnly = ImportPlan(added: 0, replaced: 0, unchanged: 9, reflections: 3);
      expect(lead(const BackupState(restore: RestorePlanned(plain, reflectionsOnly))), (
        action: CardAction.adoptRestore,
        live: true,
      ));
    });

    test('a plan that only keeps the app state up to date still adopts, so it lands', () {
      const bookkeeping = ImportPlan(added: 0, replaced: 0, unchanged: 9, reflectionState: 2);
      expect(lead(const BackupState(restore: RestorePlanned(plain, bookkeeping))), (
        action: CardAction.adoptRestore,
        live: true,
      ));
    });

    test('a plan that only brings recordings back adopts from it, so they land', () {
      const recordings = ImportPlan(added: 0, replaced: 0, unchanged: 9, recordings: 1);
      expect(lead(const BackupState(restore: RestorePlanned(plain, recordings))), (
        action: CardAction.adoptRestore,
        live: true,
      ));
    });

    test('beside a plan with nothing in it, it is the way out', () {
      expect(lead(const BackupState(restore: RestorePlanned(plain, nothing))), (
        action: CardAction.dismissRestore,
        live: true,
      ));
    });

    test('while the picker is up it is Back up, disabled', () {
      expect(lead(BackupState(measure: measure(), seal: false, restore: const RestorePicking())), (
        action: CardAction.startBackup,
        live: false,
      ));
    });

    test('while a restore step runs it is a bar', () {
      for (final flow in const <RestoreFlow>[
        RestoreChecking(sealed),
        RestoreRunning(plain, plan),
      ]) {
        expect(lead(BackupState(measure: measure(), restore: flow), unlockReady: true), (
          action: CardAction.none,
          live: false,
        ));
      }
    });
  });

  group('trailingCapsule', () {
    Capsule trail(BackupState state, {bool asking = false}) =>
        trailingCapsule(state, asking: asking);

    test('at rest, and with a result held, it picks a file to restore', () {
      for (final flow in atRest) {
        expect(trail(BackupState(restore: flow)), (
          action: CardAction.pickRestore,
          live: true,
        ), reason: '$flow');
      }
    });

    test("it closes a backup's passphrase ask", () {
      expect(trail(const BackupState(), asking: true), (action: CardAction.closeAsk, live: true));
    });

    test('while a backup or an export runs it is Restore, disabled', () {
      for (final busy in [BackupBusy.exporting, BackupBusy.archiving]) {
        expect(trail(BackupState(busy: busy)), (action: CardAction.pickRestore, live: false));
      }
    });

    test('while the picker it opened is up it is Restore, disabled', () {
      expect(trail(const BackupState(restore: RestorePicking())), (
        action: CardAction.pickRestore,
        live: false,
      ));
    });

    test('a restore waiting on the user is let go from it', () {
      for (final flow in const <RestoreFlow>[
        RestoreProbed(sealed),
        RestorePlanned(plain, plan),
        RestorePartial(plain, plan, summary),
      ]) {
        expect(trail(BackupState(restore: flow)), (
          action: CardAction.dismissRestore,
          live: true,
        ), reason: '$flow');
      }
    });

    test('while a restore step runs it does nothing', () {
      for (final flow in const <RestoreFlow>[RestoreChecking(plain), RestoreRunning(plain, plan)]) {
        expect(trail(BackupState(restore: flow)), (action: CardAction.none, live: false));
      }
    });
  });

  group('backupLive', () {
    test('at rest every control takes input', () {
      expect(backupLive(BackupState(measure: measure())), (
        seal: true,
        includeAudio: true,
        formats: true,
      ));
    });

    test('while any operation runs no other control takes input', () {
      for (final busy in [BackupBusy.exporting, BackupBusy.archiving]) {
        expect(backupLive(BackupState(measure: measure(), busy: busy)), (
          seal: false,
          includeAudio: false,
          formats: false,
        ));
      }
    });

    test('a restore under way holds every other control, even while it waits on the user', () {
      for (final flow in underWay) {
        expect(backupLive(BackupState(measure: measure(), restore: flow)), (
          seal: false,
          includeAudio: false,
          formats: false,
        ), reason: '$flow');
      }
    });

    test('a held restore result leaves every control live', () {
      for (final flow in atRest) {
        expect(backupLive(BackupState(measure: measure(), restore: flow)), (
          seal: true,
          includeAudio: true,
          formats: true,
        ), reason: '$flow');
      }
    });

    test(
      'exports need entries and the audio switch needs recordings, unmeasured counting as both',
      () {
        final empty = backupLive(BackupState(measure: measure(entries: 0, recordings: 0)));
        expect(empty.formats, isFalse);
        expect(empty.includeAudio, isFalse);
        expect(empty.seal, isTrue);
        final unmeasured = backupLive(const BackupState());
        expect(unmeasured.formats, isTrue);
        expect(unmeasured.includeAudio, isTrue);
      },
    );
  });

  group('includeAudioOf', () {
    test('audio rides along until the user says otherwise', () {
      expect(includeAudioOf(BackupState(measure: measure()), null), isTrue);
      expect(includeAudioOf(BackupState(measure: measure()), false), isFalse);
      expect(includeAudioOf(BackupState(measure: measure()), true), isTrue);
    });

    test('a journal without recordings carries none, whatever was chosen', () {
      expect(includeAudioOf(BackupState(measure: measure(recordings: 0)), true), isFalse);
      expect(includeAudioOf(BackupState(measure: measure(recordings: 0)), null), isFalse);
    });

    test('an unmeasured journal reads as having audio, the safer default', () {
      expect(includeAudioOf(const BackupState(), null), isTrue);
    });
  });
}
