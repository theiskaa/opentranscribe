import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:opentranscribe/core/export/archive_codec.dart';
import 'package:opentranscribe/core/services/export_service.dart';
import 'package:opentranscribe/core/services/import_merge.dart';
import 'package:opentranscribe/core/services/import_service.dart';
import 'package:opentranscribe/core/state/backup_cubit.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/layouts/settings/components/backup_card.dart';
import 'package:opentranscribe/view/layouts/settings/components/backup_rules.dart';
import 'package:opentranscribe/view/widgets/morph_control.dart';
import 'package:opentranscribe/view/widgets/settings_kit.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  final now = DateTime(2026, 11, 15);
  final lastBackup = DateTime(2026, 10, 21, 9);

  setUpAll(() async {
    await initializeDateFormatting();
  });

  JournalMeasure measure({
    int entries = 212,
    int recordings = 188,
    int bytes = 1400000000,
    DateTime? since,
    int newSince = 0,
  }) => JournalMeasure(
    entries: entries,
    recordings: recordings,
    approxBytes: bytes,
    since: since,
    newSince: newSince,
  );

  String facts({JournalMeasure? journal, DateTime? at, int? newSince}) => backupFacts(
    l10n,
    measure: journal,
    lastArchiveAt: at,
    newSince: newSince,
    localeTag: 'en',
    now: now,
  );

  const summary = ImportSummary(entriesAdded: 6, entriesReplaced: 3);

  const sealedProbe = ImportProbe(
    kind: ArchiveKind.sealed,
    fileName: 'j.otarchive',
    sizeBytes: 1200000,
  );
  const plainProbe = ImportProbe(kind: ArchiveKind.plainZip, fileName: 'j.zip', sizeBytes: 1200000);
  const plan = ImportPlan(added: 12, replaced: 3, unchanged: 200);
  const partial = ImportSummary(entriesAdded: 9, entriesReplaced: 0);

  group('restorePlanLine', () {
    test('a plan counts what it adds and what takes the backup version, zeros left out', () {
      const line = "Adds 12 entries · Replaces 3 with the backup's version";
      expect(restorePlanLine(l10n, plan), line);
      expect(
        restorePlanLine(l10n, const ImportPlan(added: 1, replaced: 0, unchanged: 0)),
        'Adds 1 entry',
      );
      expect(
        restorePlanLine(l10n, const ImportPlan(added: 0, replaced: 1, unchanged: 5)),
        "Replaces 1 with the backup's version",
      );
    });

    test('the reflections a plan would update are counted after its entries', () {
      expect(
        restorePlanLine(
          l10n,
          const ImportPlan(added: 0, replaced: 0, unchanged: 9, reflections: 3),
        ),
        'Updates 3 reflections',
      );
      expect(
        restorePlanLine(
          l10n,
          const ImportPlan(added: 2, replaced: 0, unchanged: 9, reflections: 1),
        ),
        'Adds 2 entries · Updates 1 reflection',
      );
    });

    test('recordings missing here are told as coming back', () {
      expect(
        restorePlanLine(l10n, const ImportPlan(added: 0, replaced: 0, unchanged: 9, recordings: 2)),
        'Brings back 2 recordings',
      );
    });

    test('a plan that only keeps the app state up to date reads as already here', () {
      const bookkeeping = ImportPlan(added: 0, replaced: 0, unchanged: 9, reflectionState: 2);
      expect(restorePlanLine(l10n, bookkeeping), 'Everything in this backup is already here.');
      expect(bookkeeping.isEmpty, isFalse);
    });

    test('a plan that would change nothing says so', () {
      expect(
        restorePlanLine(l10n, const ImportPlan(added: 0, replaced: 0, unchanged: 5)),
        'Everything in this backup is already here.',
      );
    });
  });

  group('restoreDoneLine', () {
    String done({int added = 0, int replaced = 0, int recordings = 0, int reflections = 0}) =>
        restoreDoneLine(
          l10n,
          ImportSummary(
            entriesAdded: added,
            entriesReplaced: replaced,
            recordingsBroughtBack: recordings,
            reflectionsUpdated: reflections,
          ),
        );

    test('every part a reader sees is joined, zeros left out, with no lead word', () {
      expect(
        done(added: 2, replaced: 1, recordings: 2, reflections: 1),
        '2 entries added · 1 replaced · 2 recordings back · 1 reflection updated',
      );
      expect(done(added: 1), '1 entry added');
      expect(done(replaced: 3), '3 replaced');
      expect(done(added: 2, reflections: 3), '2 entries added · 3 reflections updated');
    });

    test('recordings alone are told as coming back', () {
      expect(done(recordings: 1), '1 recording back');
    });

    test('a restore that changed nothing a reader sees says everything was already here', () {
      expect(done(), 'Restored. Everything was already here.');
    });
  });

  group('restorePartialLine', () {
    String partial(ImportPlan plan, ImportSummary restored, {bool reflectionsLeft = false}) =>
        restorePartialLine(l10n, plan, restored, reflectionsLeft: reflectionsLeft);
    const planned = ImportPlan(added: 4, replaced: 1, unchanged: 0, reflections: 2);

    test('entries still to land are counted against the entries planned', () {
      expect(
        partial(planned, const ImportSummary(entriesAdded: 2, entriesReplaced: 0)),
        'Stopped partway: 2 of 5 entries restored. Restore again to finish.',
      );
    });

    test('recordings to bring back count beside the entries', () {
      const recordingsOnly = ImportPlan(added: 0, replaced: 0, unchanged: 4, recordings: 3);
      expect(
        partial(
          recordingsOnly,
          const ImportSummary(entriesAdded: 0, entriesReplaced: 0, recordingsBroughtBack: 1),
        ),
        'Stopped partway: 1 of 3 entries restored. Restore again to finish.',
      );
      const mixed = ImportPlan(added: 2, replaced: 0, unchanged: 4, recordings: 2);
      expect(
        partial(
          mixed,
          const ImportSummary(entriesAdded: 2, entriesReplaced: 0, recordingsBroughtBack: 1),
        ),
        'Stopped partway: 3 of 4 entries restored. Restore again to finish.',
      );
    });

    test('a plan with no entry or recording to count says it stopped, plainly', () {
      const reflectionsOnly = ImportPlan(added: 0, replaced: 0, unchanged: 4, reflections: 2);
      expect(
        partial(reflectionsOnly, const ImportSummary(entriesAdded: 0, entriesReplaced: 0)),
        l10n.restorePartialGeneric,
      );
    });

    test(
      'a reflections-only plan that broke in its reflections still says it stopped, plainly',
      () {
        const reflectionsOnly = ImportPlan(added: 0, replaced: 0, unchanged: 4, reflections: 2);
        expect(
          partial(
            reflectionsOnly,
            const ImportSummary(entriesAdded: 0, entriesReplaced: 0),
            reflectionsLeft: true,
          ),
          l10n.restorePartialGeneric,
        );
      },
    );

    test('once every entry was through adoption, it says the reflections did not finish', () {
      expect(
        partial(
          planned,
          const ImportSummary(entriesAdded: 4, entriesReplaced: 1),
          reflectionsLeft: true,
        ),
        l10n.restorePartialReflections,
      );
    });

    test('a journal edited between stage and adopt never reads more done than planned', () {
      expect(
        partial(planned, const ImportSummary(entriesAdded: 7, entriesReplaced: 0)),
        'Stopped partway: 5 of 5 entries restored. Restore again to finish.',
      );
    });
  });

  group('restoreFailureText', () {
    ImportProbe zip(ZipContents contents) => ImportProbe(
      kind: ArchiveKind.plainZip,
      fileName: 'j.zip',
      sizeBytes: 9,
      contents: contents,
    );
    String damaged(ImportProbe? probe) =>
        restoreFailureText(l10n, RestoreFailure.damaged, probe: probe);

    test('a file that could not be read at all says it could not be opened', () {
      expect(damaged(null), l10n.restoreUnopenable);
    });

    test('a read file whose bytes are no archive is not a backup', () {
      const unknown = ImportProbe(kind: ArchiveKind.unknown, fileName: 'x.pdf', sizeBytes: 9);
      expect(damaged(unknown), l10n.importNotArchive);
    });

    test('a zip laid out like a copy for other apps says so', () {
      expect(damaged(zip(ZipContents.export)), l10n.restoreExportNotBackup);
    });

    test('a zip of anything else without a manifest is not a backup', () {
      expect(damaged(zip(ZipContents.foreign)), l10n.importNotArchive);
    });

    test('a backup that would not read says so, whether its peek failed or its manifest read', () {
      expect(damaged(zip(ZipContents.unreadable)), l10n.restoreUnreadable);
      expect(damaged(zip(ZipContents.backup)), l10n.restoreUnreadable);
      expect(damaged(sealedProbe), l10n.restoreUnreadable);
    });

    test('a compressed zip without a manifest is told by its layout, not as re-zipped', () {
      String rezipped(ImportProbe probe) =>
          restoreFailureText(l10n, RestoreFailure.rezipped, probe: probe);
      expect(rezipped(zip(ZipContents.export)), l10n.restoreExportNotBackup);
      expect(rezipped(zip(ZipContents.foreign)), l10n.importNotArchive);
      expect(rezipped(zip(ZipContents.backup)), l10n.importRezipped);
    });

    test('a full disk says it ran out of space', () {
      expect(restoreFailureText(l10n, RestoreFailure.noSpace), l10n.restoreNoSpace);
    });

    test('a newer app and a re-zip each name their own way out', () {
      expect(restoreFailureText(l10n, RestoreFailure.newerVersion), l10n.importNewerVersion);
      expect(restoreFailureText(l10n, RestoreFailure.rezipped), l10n.importRezipped);
    });
  });

  group('backupFacts', () {
    test(
      'a measured journal with a backup tells recordings, size, the date and what came after',
      () {
        expect(
          facts(journal: measure(), at: lastBackup, newSince: 18),
          '188 recordings · 1.4 GB · Last backup Oct 21 · 18 new since',
        );
      },
    );

    test('nothing new since the backup is left out rather than counted as zero', () {
      expect(
        facts(journal: measure(), at: lastBackup, newSince: 0),
        '188 recordings · 1.4 GB · Last backup Oct 21',
      );
    });

    test('a new-since count not yet measured against the backup is left out', () {
      expect(
        facts(journal: measure(), at: lastBackup),
        '188 recordings · 1.4 GB · Last backup Oct 21',
      );
    });

    test('a journal that was never backed up says so and dates nothing', () {
      expect(facts(journal: measure()), '188 recordings · 1.4 GB · No backup yet');
    });

    test('a journal with no recordings and no weight drops both parts', () {
      expect(
        facts(journal: measure(recordings: 0, bytes: 0), at: lastBackup),
        'Last backup Oct 21',
      );
    });

    test('before the first measure only the backup date is known', () {
      expect(facts(at: lastBackup), 'Last backup Oct 21');
    });

    test('an empty journal has nothing to back up, whatever an old backup says', () {
      expect(
        facts(journal: measure(entries: 0), at: lastBackup, newSince: 0),
        'Nothing to back up yet.',
      );
    });

    test('a backup from an earlier year carries its year', () {
      expect(
        facts(journal: measure(), at: DateTime(2025, 3, 2)),
        '188 recordings · 1.4 GB · Last backup Mar 2, 2025',
      );
    });

    test('a backup made today says so instead of dating itself, and yesterday keeps its date', () {
      expect(
        facts(journal: measure(), at: DateTime(2026, 11, 15, 8), newSince: 2),
        '188 recordings · 1.4 GB · Backed up today · 2 new since',
      );
      expect(facts(journal: measure(), at: DateTime(2026, 11, 14, 23)), contains('Nov 14'));
    });
  });

  group('backupTitle', () {
    test('counts the entries once measured, and names an empty journal', () {
      expect(backupTitle(l10n, measure()), '212 entries');
      expect(backupTitle(l10n, measure(entries: 1)), '1 entry');
      expect(backupTitle(l10n, measure(entries: 0)), 'No entries yet');
    });

    test('holds an ellipsis until the first measure, since zero would read as empty', () {
      expect(backupTitle(l10n, null), '…');
    });
  });

  group('backupCardLine', () {
    final state = BackupState(
      measure: measure(since: lastBackup, newSince: 18),
      lastArchiveAt: lastBackup,
    );

    ToneLine line(BackupNote? note) =>
        backupCardLine(l10n, state, note: note, localeTag: 'en', now: now);

    test('with nothing to tell it reads the facts, newSince taken from the state', () {
      expect(line(null), (
        text: '188 recordings · 1.4 GB · Last backup Oct 21 · 18 new since',
        tone: NoteTone.quiet,
      ));
    });

    test('a shared backup is told as done, and says when it was encrypted', () {
      expect(line(archiveNoteOf(BackupActionResult.shared, sealed: false)), (
        text: 'Backed up just now',
        tone: NoteTone.positive,
      ));
      expect(line(archiveNoteOf(BackupActionResult.shared, sealed: true)), (
        text: 'Backed up just now, encrypted',
        tone: NoteTone.positive,
      ));
    });

    test('a failed backup names its cause in the danger ink', () {
      expect(line(archiveNoteOf(BackupActionResult.failedNoSpace, sealed: true)), (
        text: l10n.exportNoSpaceBody,
        tone: NoteTone.negative,
      ));
      expect(line(archiveNoteOf(BackupActionResult.failed, sealed: false)), (
        text: l10n.exportFailedBody,
        tone: NoteTone.negative,
      ));
    });

    ToneLine during(RestoreFlow flow, {BackupNote? note}) => backupCardLine(
      l10n,
      BackupState(measure: state.measure, lastArchiveAt: lastBackup, restore: flow),
      note: note,
      localeTag: 'en',
      now: now,
    );

    test('a file that opens, or waits for its passphrase, is named with its size', () {
      expect(during(const RestoreProbed(sealedProbe)), (
        text: 'j.otarchive · 1.2 MB',
        tone: NoteTone.quiet,
      ));
      expect(during(const RestoreChecking(plainProbe)).text, 'j.zip · 1.2 MB');
    });

    test('a plan waiting on the user shows its two numbers', () {
      expect(during(const RestorePlanned(plainProbe, plan)), (
        text: "Adds 12 entries · Replaces 3 with the backup's version",
        tone: NoteTone.quiet,
      ));
    });

    test('a running restore asks for the app to stay open', () {
      expect(
        during(const RestoreRunning(plainProbe, plan, progress: 0.4)).text,
        'Keep the app open until it finishes.',
      );
    });

    test('a finished restore is told as its done line, in the positive ink', () {
      expect(during(const RestoreDone(plainProbe, summary)), (
        text: '6 entries added · 3 replaced',
        tone: NoteTone.positive,
      ));
    });

    test(
      'a restore that stopped partway says so in the danger ink, its reflections left in words',
      () {
        expect(during(const RestorePartial(plainProbe, plan, summary, reflectionsLeft: true)), (
          text: l10n.restorePartialReflections,
          tone: NoteTone.negative,
        ));
      },
    );

    test('a restore that stopped partway counts what it restored of what it planned', () {
      expect(during(const RestorePartial(plainProbe, plan, summary)), (
        text: 'Stopped partway: 9 of 15 entries restored. Restore again to finish.',
        tone: NoteTone.negative,
      ));
    });

    test('a failed restore says why in the danger ink', () {
      expect(during(const RestoreFailed(RestoreFailure.newerVersion, probe: plainProbe)), (
        text: l10n.importNewerVersion,
        tone: NoteTone.negative,
      ));
    });

    test("a restore's line takes the card over any backup note it held", () {
      expect(
        during(
          const RestoreDone(plainProbe, summary),
          note: archiveNoteOf(BackupActionResult.shared, sealed: true),
        ).tone,
        NoteTone.positive,
      );
      expect(
        during(
          const RestorePicking(),
          note: archiveNoteOf(BackupActionResult.shared, sealed: true),
        ).text,
        'Backed up just now, encrypted',
      );
    });

    test("an export's outcome belongs to its row and leaves the card's facts alone", () {
      expect(line(exportNoteOf('md', BackupActionResult.shared)).tone, NoteTone.quiet);
    });
  });

  Capsule lead(BackupState state, {bool asking = false, bool ready = false}) =>
      leadingCapsule(state, asking: asking, passphraseReady: ready, unlockReady: ready);

  group('leadingFace', () {
    MorphFace face(BackupState state) => leadingFace(l10n, state, lead(state), localeTag: 'en');
    String label(BackupState state) =>
        leadingSemanticLabel(l10n, state, lead(state), localeTag: 'en');

    test('at rest and while an export runs it is the Back up button', () {
      for (final busy in [BackupBusy.none, BackupBusy.exporting]) {
        final button = face(BackupState(busy: busy)) as MorphButton;
        expect(button.label, 'Back up');
        expect(button.variant, MorphVariant.primary);
      }
    });

    test('a pack still in its grace is the loader-only bar', () {
      final bar =
          face(const BackupState(busy: BackupBusy.archiving, phase: BackupPhase.packing))
              as MorphBar;
      expect(bar.fill, isNull);
      expect(bar.label, isEmpty);
    });

    test('a packing backup fills to the whole percent its label reads', () {
      const state = BackupState(
        busy: BackupBusy.archiving,
        phase: BackupPhase.packing,
        progress: 0.43,
      );
      final bar = face(state) as MorphBar;
      expect(bar.fill, 0.43);
      expect(bar.label, '43%');
    });

    test('a sealing backup is a full, still bar that says it is encrypting', () {
      final bar =
          face(const BackupState(busy: BackupBusy.archiving, phase: BackupPhase.sealing))
              as MorphBar;
      expect(bar.fill, 1);
      expect(bar.label, 'Encrypting…');
    });

    test('a backup waiting on the share sheet is a full, still bar ready to share', () {
      final bar =
          face(const BackupState(busy: BackupBusy.archiving, phase: BackupPhase.sharing))
              as MorphBar;
      expect(bar.fill, 1);
      expect(bar.label, 'Ready to share');
    });

    test('while the picker is up it stays the Back up button', () {
      expect((face(const BackupState(restore: RestorePicking())) as MorphButton).label, 'Back up');
    });

    test('checking a file is a bar with no measure that says it checks, or unlocks', () {
      final plain = face(const BackupState(restore: RestoreChecking(plainProbe))) as MorphBar;
      expect(plain.fill, isNull);
      expect(plain.label, 'Checking…');
      final sealed = face(const BackupState(restore: RestoreChecking(sealedProbe))) as MorphBar;
      expect(sealed.label, 'Unlocking…');
    });

    test('a running restore inside its grace is a bar with no measure and no words', () {
      final bar = face(const BackupState(restore: RestoreRunning(plainProbe, plan))) as MorphBar;
      expect(bar.fill, isNull);
      expect(bar.label, isEmpty);
    });

    test('a running restore fills to the whole percent its label reads', () {
      final bar =
          face(const BackupState(restore: RestoreRunning(plainProbe, plan, progress: 0.43)))
              as MorphBar;
      expect(bar.fill, 0.43);
      expect(bar.label, '43%');
    });

    test("while the restore waits on the user it is the card's inked next step", () {
      final cases = {
        const RestoreProbed(sealedProbe): 'Unlock',
        const RestorePlanned(plainProbe, plan): 'Restore',
        const RestorePartial(plainProbe, plan, partial): 'Restore again',
      };
      for (final MapEntry(key: flow, value: words) in cases.entries) {
        final state = BackupState(restore: flow);
        final button = face(state) as MorphButton;
        expect(button.label, words);
        expect(button.variant, MorphVariant.primary);
        expect(label(state), words);
      }
    });

    test('a plan that would change nothing leaves Done as the one thing to press', () {
      const empty = RestorePlanned(plainProbe, ImportPlan(added: 0, replaced: 0, unchanged: 9));
      final button = face(const BackupState(restore: empty)) as MorphButton;
      expect(button.label, 'Done');
      expect(button.variant, MorphVariant.primary);
    });

    test('a held restore result leaves it the Back up button', () {
      for (final flow in const <RestoreFlow>[
        RestoreDone(plainProbe, summary),
        RestoreFailed(RestoreFailure.damaged),
      ]) {
        expect((face(BackupState(restore: flow)) as MorphButton).label, 'Back up');
      }
    });

    test('VoiceOver hears the step the bar shows', () {
      expect(label(const BackupState()), 'Back up');
      expect(
        label(const BackupState(busy: BackupBusy.archiving, phase: BackupPhase.packing)),
        'Backing up',
      );
      expect(
        label(
          const BackupState(busy: BackupBusy.archiving, phase: BackupPhase.packing, progress: 0.5),
        ),
        'Backing up, 50%',
      );
      expect(
        label(const BackupState(busy: BackupBusy.archiving, phase: BackupPhase.sealing)),
        'Encrypting…',
      );
      expect(
        label(const BackupState(busy: BackupBusy.archiving, phase: BackupPhase.sharing)),
        'Ready to share',
      );
      expect(
        label(const BackupState(restore: RestoreRunning(plainProbe, plan, progress: 0.5))),
        'Restoring, 50%',
      );
      expect(label(const BackupState(restore: RestoreRunning(plainProbe, plan))), 'Restoring');
      expect(label(const BackupState(restore: RestoreChecking(sealedProbe))), 'Unlocking…');
      expect(label(const BackupState(restore: RestorePicking())), 'Back up');
    });
  });

  group('trailingSeatOpen', () {
    test('it stays open beside a capsule that is a button', () {
      for (final state in const <BackupState>[
        BackupState(),
        BackupState(busy: BackupBusy.exporting),
        BackupState(restore: RestorePicking()),
        BackupState(restore: RestoreProbed(sealedProbe)),
        BackupState(restore: RestorePlanned(plainProbe, plan)),
      ]) {
        expect(trailingSeatOpen(lead(state)), isTrue, reason: '$state');
      }
    });

    test('it closes while the leading capsule is a bar', () {
      for (final state in const <BackupState>[
        BackupState(busy: BackupBusy.archiving),
        BackupState(restore: RestoreChecking(plainProbe)),
        BackupState(restore: RestoreRunning(plainProbe, plan)),
      ]) {
        expect(trailingSeatOpen(lead(state)), isFalse, reason: '$state');
      }
    });

    test('a plan that only updates reflections keeps it open beside Restore', () {
      const reflectionsOnly = ImportPlan(added: 0, replaced: 0, unchanged: 9, reflections: 3);
      expect(
        trailingSeatOpen(
          lead(const BackupState(restore: RestorePlanned(plainProbe, reflectionsOnly))),
        ),
        isTrue,
      );
    });

    test('a plan that would change nothing closes it beside its lone Done', () {
      const empty = RestorePlanned(plainProbe, ImportPlan(added: 0, replaced: 0, unchanged: 9));
      expect(trailingSeatOpen(lead(const BackupState(restore: empty))), isFalse);
    });
  });

  group('backupCancellable', () {
    test('a running restore is never offered a cancel', () {
      expect(
        backupCancellable(
          const BackupState(restore: RestoreRunning(plainProbe, plan, progress: 0.4)),
        ),
        isFalse,
      );
    });

    test('a backup can be called off only while its pack shows a measure', () {
      expect(
        backupCancellable(
          const BackupState(busy: BackupBusy.archiving, phase: BackupPhase.packing),
        ),
        isFalse,
      );
      expect(
        backupCancellable(
          const BackupState(busy: BackupBusy.archiving, phase: BackupPhase.packing, progress: 0.2),
        ),
        isTrue,
      );
      expect(
        backupCancellable(
          const BackupState(busy: BackupBusy.exporting, phase: BackupPhase.packing, progress: 0.2),
        ),
        isFalse,
      );
    });
  });

  group('trailingFace', () {
    MorphButton face(BackupState state, {bool asking = false}) =>
        trailingFace(l10n, state, trailingCapsule(state, asking: asking)) as MorphButton;
    String label(BackupState state, {bool asking = false}) =>
        trailingSemanticLabel(l10n, state, trailingCapsule(state, asking: asking));

    test('at rest, with a result held, and while the picker is up, it is the quiet Restore', () {
      for (final flow in const <RestoreFlow>[
        RestoreIdle(),
        RestorePicking(),
        RestoreDone(plainProbe, summary),
        RestoreFailed(RestoreFailure.rezipped),
      ]) {
        final button = face(BackupState(restore: flow));
        expect(button.label, 'Restore');
        expect(button.variant, MorphVariant.secondary);
        expect(label(BackupState(restore: flow)), 'Restore backup');
      }
    });

    test('it is Cancel while a backup asks for its passphrase', () {
      expect(face(const BackupState(), asking: true).label, 'Cancel');
      expect(label(const BackupState(), asking: true), 'Cancel');
    });

    test('while the restore waits on the user it is the quiet way out', () {
      final cases = {
        const RestoreProbed(sealedProbe): 'Cancel',
        const RestorePlanned(plainProbe, plan): 'Cancel',
        const RestorePartial(plainProbe, plan, partial): 'Done',
      };
      for (final MapEntry(key: flow, value: words) in cases.entries) {
        final button = face(BackupState(restore: flow));
        expect(button.label, words);
        expect(button.variant, MorphVariant.secondary);
        expect(label(BackupState(restore: flow)), words);
      }
    });
  });

  group('the restore passphrase', () {
    test('the field shows while a sealed file waits for it and while it is checked', () {
      expect(restoreAsksPassphrase(const RestoreProbed(sealedProbe)), isTrue);
      expect(restoreAsksPassphrase(const RestoreChecking(sealedProbe)), isTrue);
      expect(restoreAsksPassphrase(const RestoreChecking(plainProbe)), isFalse);
      expect(restoreAsksPassphrase(const RestorePlanned(sealedProbe, plan)), isFalse);
      expect(restoreAsksPassphrase(const RestoreIdle()), isFalse);
    });

    test(
      'a failed attempt is counted while the file waits again, and none while it is checked',
      () {
        expect(restoreUnlockAttempt(const RestoreProbed(sealedProbe)), 0);
        expect(restoreUnlockAttempt(const RestoreProbed(sealedProbe, attempt: 2)), 2);
        expect(restoreUnlockAttempt(const RestoreChecking(sealedProbe)), 0);
      },
    );
  });
}
