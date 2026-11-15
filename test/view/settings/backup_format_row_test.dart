import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/state/backup_cubit.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/layouts/settings/components/backup_format_row.dart';
import 'package:opentranscribe/view/layouts/settings/components/backup_rules.dart';
import 'package:opentranscribe/view/widgets/settings_kit.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group('exportRowRun', () {
    test('only the row whose export runs shows it, with its pack measure', () {
      const state = BackupState(
        busy: BackupBusy.exporting,
        phase: BackupPhase.packing,
        exportingId: 'md',
        progress: 0.3,
      );
      expect(exportRowRun(state, 'md'), (running: true, waiting: false, fraction: 0.3));
      expect(exportRowRun(state, 'web'), (running: false, waiting: false, fraction: null));
    });

    test('a running row whose files are built waits on the share sheet', () {
      const state = BackupState(
        busy: BackupBusy.exporting,
        phase: BackupPhase.sharing,
        exportingId: 'md',
      );
      expect(exportRowRun(state, 'md'), (running: true, waiting: true, fraction: null));
    });

    test('a backup on its way to the share sheet runs no format row', () {
      const state = BackupState(busy: BackupBusy.archiving, phase: BackupPhase.sharing);
      expect(exportRowRun(state, 'md'), (running: false, waiting: false, fraction: null));
    });
  });

  group('exportRowLine', () {
    test('a shared export is told on its own row only', () {
      final note = exportNoteOf('md', BackupActionResult.shared);
      expect(exportRowLine(l10n, note, 'md'), (text: 'Shared just now', tone: NoteTone.positive));
      expect(exportRowLine(l10n, note, 'obsidian'), isNull);
    });

    test('a failed export names its cause on its row', () {
      expect(exportRowLine(l10n, exportNoteOf('web', BackupActionResult.failedTooLarge), 'web'), (
        text: l10n.exportTooLargeBody,
        tone: NoteTone.negative,
      ));
    });

    test("a backup's outcome leaves every row its own line", () {
      expect(
        exportRowLine(l10n, archiveNoteOf(BackupActionResult.shared, sealed: true), 'md'),
        isNull,
      );
    });

    test('a waiting row says where the files go, over any outcome it held', () {
      expect(
        exportRowLine(l10n, exportNoteOf('md', BackupActionResult.failed), 'md', waiting: true),
        (text: 'Choose where it goes', tone: NoteTone.quiet),
      );
    });
  });
}
