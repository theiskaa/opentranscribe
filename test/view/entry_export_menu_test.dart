import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/models/exporter_descriptor.dart';
import 'package:opentranscribe/core/state/backup_cubit.dart';
import 'package:opentranscribe/l10n/generated/app_localizations.dart';
import 'package:opentranscribe/view/layouts/entry/components/entry_export_menu.dart';
import 'package:opentranscribe/view/widgets/app_menu.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  const descriptors = [
    ExporterDescriptor(exporterId: 'markdown', format: ExportFormat.markdown, logo: 'm.svg'),
    ExporterDescriptor(exporterId: 'obsidian', format: ExportFormat.obsidian, logo: 'o.svg'),
    ExporterDescriptor(exporterId: 'html', format: ExportFormat.web, logo: 'w.svg'),
  ];
  final markdownMark = Uint8List.fromList([1, 2, 3]);

  List<String?> ids(List<AppMenuItem> items) => [for (final i in items) i.id];

  test(
    'the export row opens the formats in registry order, then the audio check in its own section',
    () {
      final item = entryExportMenuItem(
        descriptors: descriptors,
        nameOf: (format) => format.name,
        marks: const {},
        hasAudio: true,
        includeAudio: true,
        label: 'Export',
        includeAudioLabel: 'Include audio',
      );
      expect(item.id, entryExportId);
      expect(ids(item.children), [
        entryExportFormatItemId('markdown'),
        entryExportFormatItemId('obsidian'),
        entryExportFormatItemId('html'),
        null,
        entryExportAudioId,
      ]);
      expect(item.children[3].isDivider, isTrue);
      expect([for (final c in item.children.take(3)) c.label], ['markdown', 'obsidian', 'web']);
    },
  );

  test('an entry without a recording offers no audio check', () {
    final item = entryExportMenuItem(
      descriptors: descriptors,
      nameOf: (format) => format.name,
      marks: const {},
      hasAudio: false,
      includeAudio: true,
      label: 'Export',
      includeAudioLabel: 'Include audio',
    );
    expect(ids(item.children), isNot(contains(entryExportAudioId)));
    expect(item.children.any((c) => c.isDivider), isFalse);
    expect(item.children, hasLength(descriptors.length));
  });

  test('the audio check shows its state and keeps the menu up to be flipped again', () {
    for (final on in [true, false]) {
      final check = entryExportMenuItem(
        descriptors: descriptors,
        nameOf: (format) => format.name,
        marks: const {},
        hasAudio: true,
        includeAudio: on,
        label: 'Export',
        includeAudioLabel: 'Include audio',
      ).children.last;
      expect(check.selected, on);
      expect(check.keepsPresented, isTrue);
    }
  });

  test('a format wears its mark once rasterized and goes bare until then', () {
    final children = entryExportMenuItem(
      descriptors: descriptors,
      nameOf: (format) => format.name,
      marks: {'markdown': markdownMark},
      hasAudio: false,
      includeAudio: true,
      label: 'Export',
      includeAudioLabel: 'Include audio',
    ).children;
    expect(children.first.iconBytes, markdownMark);
    expect(children[1].iconBytes, isNull);
    expect(children.every((c) => !c.keepsPresented), isTrue);
  });

  test('a format row id names its exporter and no other id does', () {
    expect(entryExportFormatOf(entryExportFormatItemId('obsidian')), 'obsidian');
    expect(entryExportFormatOf(entryExportAudioId), isNull);
    expect(entryExportFormatOf(entryExportId), isNull);
    expect(entryExportFormatOf('de-DE'), isNull);
  });

  test('a failed export names the two causes a user can act on, and reads plain otherwise', () {
    expect(
      entryExportFailureLabel(l10n, BackupActionResult.failedTooLarge),
      l10n.exportEntryTooLarge,
    );
    expect(
      entryExportFailureLabel(l10n, BackupActionResult.failedNoSpace),
      l10n.exportEntryNoSpace,
    );
    expect(entryExportFailureLabel(l10n, BackupActionResult.failed), l10n.exportEntryFailed);
  });
}
