import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/export/journal_exporter.dart';
import 'package:opentranscribe/core/export/share_export.dart';
import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/models/exporter_descriptor.dart';
import 'package:opentranscribe/core/services/export_service.dart';
import 'package:opentranscribe/core/state/backup_cubit.dart';
import 'package:opentranscribe/core/state/entry_export_cubit.dart';

class _ScriptedExport implements ExportService {
  bool shares = true;
  Object? error;

  Completer<void>? packGate;
  Completer<void>? sheetGate;

  final List<({String entryId, String exporterId, bool includeAudio})> calls = [];

  @override
  Future<bool> shareEntry(
    String entryId, {
    required String exporterId,
    required bool includeAudio,
    required ExportStrings strings,
    void Function()? onSharing,
  }) async {
    calls.add((entryId: entryId, exporterId: exporterId, includeAudio: includeAudio));
    await packGate?.future;
    final error = this.error;
    if (error != null) throw error;
    onSharing?.call();
    await sheetGate?.future;
    return shares;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const strings = ExportStrings(
    untitledEntry: 'Untitled',
    transcriptHeading: 'Transcript',
    quietReflection: 'Quiet',
    periodLabels: {},
  );
  const descriptors = [
    ExporterDescriptor(exporterId: 'markdown', format: ExportFormat.markdown, logo: 'm.svg'),
  ];
  final withAudio = Entry(
    id: 'e1',
    createdAt: DateTime.utc(2026, 8, 7),
    audioPath: 'otr-1.m4a',
    duration: const Duration(seconds: 5),
  );
  final textOnly = Entry(
    id: 'e2',
    createdAt: DateTime.utc(2026, 8, 7),
    audioPath: null,
    duration: const Duration(seconds: 5),
  );

  EntryExportCubit build(_ScriptedExport export, {Duration grace = Duration.zero}) {
    final cubit = EntryExportCubit(export: export, descriptors: descriptors, preparingGrace: grace);
    addTearDown(cubit.close);
    return cubit;
  }

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('include audio starts on and holds what the menu flips it to', () {
    final cubit = build(_ScriptedExport());
    expect(cubit.state.includeAudio, isTrue);
    cubit.toggleAudio();
    expect(cubit.state.includeAudio, isFalse);
    cubit.toggleAudio();
    expect(cubit.state.includeAudio, isTrue);
  });

  test('an entry with a recording exports it while the check is on', () async {
    final export = _ScriptedExport();
    final cubit = build(export);
    await cubit.export(withAudio, exporterId: 'markdown', strings: strings);
    expect(export.calls.single, (entryId: 'e1', exporterId: 'markdown', includeAudio: true));
  });

  test('a cleared check exports the words alone', () async {
    final export = _ScriptedExport();
    final cubit = build(export)..toggleAudio();
    await cubit.export(withAudio, exporterId: 'markdown', strings: strings);
    expect(export.calls.single.includeAudio, isFalse);
  });

  test('a transcript-only entry never asks for audio, whatever the check says', () async {
    final export = _ScriptedExport();
    final cubit = build(export);
    await cubit.export(textOnly, exporterId: 'markdown', strings: strings);
    expect(export.calls.single.includeAudio, isFalse);
  });

  test('a completed share answers shared and leaves nothing to tell', () async {
    final cubit = build(_ScriptedExport());
    final result = await cubit.export(withAudio, exporterId: 'markdown', strings: strings);
    expect(result, BackupActionResult.shared);
    expect(cubit.state, const EntryExportState());
  });

  test('a dismissed share sheet is a quiet cancel', () async {
    final cubit = build(_ScriptedExport()..shares = false);
    final result = await cubit.export(withAudio, exporterId: 'markdown', strings: strings);
    expect(result, BackupActionResult.cancelled);
    expect(cubit.state.failure, isNull);
    expect(entryExportLineOf(cubit.state), EntryExportLine.none);
  });

  test('a share sheet that never presented stays as quiet as a cancel', () async {
    final cubit = build(
      _ScriptedExport()..error = const ShareExportException('busy', ShareExportException.busy),
    );
    final result = await cubit.export(withAudio, exporterId: 'markdown', strings: strings);
    expect(result, BackupActionResult.cancelled);
    expect(cubit.state.failure, isNull);
  });

  test('a broken pack is held as a failure for the bar to tell', () async {
    final cubit = build(_ScriptedExport()..error = StateError('broke'));
    final result = await cubit.export(withAudio, exporterId: 'markdown', strings: strings);
    expect(result, BackupActionResult.failed);
    expect(cubit.state.failure, BackupActionResult.failed);
    expect(cubit.state.running, isFalse);
    expect(entryExportLineOf(cubit.state), EntryExportLine.failed);
  });

  test('a full disk keeps its cause', () async {
    final cubit = build(
      _ScriptedExport()..error = const FileSystemException('full', 'p', OSError('no space', 28)),
    );
    await cubit.export(withAudio, exporterId: 'markdown', strings: strings);
    expect(cubit.state.failure, BackupActionResult.failedNoSpace);
  });

  test('a dismissed failure leaves the bar empty', () async {
    final cubit = build(_ScriptedExport()..error = StateError('broke'));
    await cubit.export(withAudio, exporterId: 'markdown', strings: strings);
    cubit.dismissFailure();
    expect(cubit.state.failure, isNull);
    expect(entryExportLineOf(cubit.state), EntryExportLine.none);
  });

  test('the next export lets the last failure go as it starts', () async {
    final export = _ScriptedExport()..error = StateError('broke');
    final cubit = build(export);
    await cubit.export(withAudio, exporterId: 'markdown', strings: strings);
    export
      ..error = null
      ..packGate = Completer<void>();
    final run = cubit.export(withAudio, exporterId: 'markdown', strings: strings);
    expect(cubit.state.failure, isNull);
    export.packGate!.complete();
    await run;
  });

  test('a pack past the grace says it is preparing, until the share sheet takes it', () async {
    final export = _ScriptedExport()
      ..packGate = Completer<void>()
      ..sheetGate = Completer<void>();
    final cubit = build(export);
    final run = cubit.export(withAudio, exporterId: 'markdown', strings: strings);
    await settle();
    expect(entryExportLineOf(cubit.state), EntryExportLine.preparing);
    export.packGate!.complete();
    await settle();
    expect(cubit.state.running, isTrue);
    expect(entryExportLineOf(cubit.state), EntryExportLine.none);
    export.sheetGate!.complete();
    await run;
    expect(cubit.state.running, isFalse);
  });

  test('a pack that lands inside the grace never says it is preparing', () async {
    final export = _ScriptedExport()..sheetGate = Completer<void>();
    final cubit = build(export, grace: const Duration(hours: 1));
    final seen = <EntryExportLine>[];
    final sub = cubit.stream.listen((s) => seen.add(entryExportLineOf(s)));
    final run = cubit.export(withAudio, exporterId: 'markdown', strings: strings);
    await settle();
    export.sheetGate!.complete();
    await run;
    await sub.cancel();
    expect(seen, isNot(contains(EntryExportLine.preparing)));
  });

  test('a second tap while one export runs is a quiet cancel that exports nothing', () async {
    final export = _ScriptedExport()..packGate = Completer<void>();
    final cubit = build(export);
    final first = cubit.export(withAudio, exporterId: 'markdown', strings: strings);
    final second = await cubit.export(withAudio, exporterId: 'markdown', strings: strings);
    expect(second, BackupActionResult.cancelled);
    export.packGate!.complete();
    await first;
    expect(export.calls, hasLength(1));
  });

  test('an export finishing after the screen closed answers without emitting', () async {
    final export = _ScriptedExport()..packGate = Completer<void>();
    final cubit = EntryExportCubit(export: export, descriptors: descriptors);
    final run = cubit.export(withAudio, exporterId: 'markdown', strings: strings);
    await cubit.close();
    export.packGate!.complete();
    expect(await run, BackupActionResult.shared);
  });

  test('a failure outranks the wait in the bar', () {
    const state = EntryExportState(
      running: true,
      preparing: true,
      failure: BackupActionResult.failed,
    );
    expect(entryExportLineOf(state), EntryExportLine.failed);
  });

  test('a stale preparing flag says nothing once the run is over', () {
    expect(entryExportLineOf(const EntryExportState(preparing: true)), EntryExportLine.none);
  });
}
