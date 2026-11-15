import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:opentranscribe/core/export/archive_codec.dart';
import 'package:opentranscribe/core/export/archive_crypto.dart';
import 'package:opentranscribe/core/export/archive_manifest.dart';
import 'package:opentranscribe/core/export/file_names.dart';
import 'package:opentranscribe/core/export/share_export.dart';
import 'package:opentranscribe/core/export/staging_registry.dart';
import 'package:opentranscribe/core/export/stored_zip.dart';
import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/models/reflection.dart';
import 'package:opentranscribe/core/services/import_merge.dart';
import 'package:opentranscribe/core/services/reflection_service.dart';
import 'package:opentranscribe/core/services/transcription_service.dart';

/// Restores a native archive into the journal: pick, sniff, decrypt when
/// sealed, parse EVERYTHING strictly, stage audio and plan ([stage]), then
/// adopt through the lifecycle owners ([adopt]). All-validate-before-any-write:
/// until adoption starts, nothing outside a temp staging directory is
/// touched, so a failed decrypt or a malformed archive provably changes
/// nothing on disk. Merge is by entry id and idempotent. An archive failure
/// surfaces as [ArchiveException], a sealed archive without its passphrase
/// as ArgumentError (the UI probes first), and anything else as it was
/// thrown: before adoption nothing changed, during it the journal may have.
class ImportService {
  ImportService({
    required this._transcription,
    required this._reflections,
    required this._share,
    required this._staging,
  });

  final TranscriptionService _transcription;
  final ReflectionService _reflections;
  final ShareExport _share;
  final StagingRegistry _staging;

  /// Opens the document picker; null when the user cancels.
  Future<String?> pickArchive() => _share.pickArchive();

  /// What the picked file is before any import work: the kind its first bytes
  /// claim, so the UI knows whether to ask for a passphrase, plus the name,
  /// size, and for a plain zip what its directory listing shows.
  Future<ImportProbe> probe(String path) async {
    final file = File(path);
    final kind = await sniffArchive(file);
    return ImportProbe(
      kind: kind,
      fileName: baseName(path),
      sizeBytes: await file.length(),
      contents: kind == ArchiveKind.plainZip ? await _peekContents(file) : null,
    );
  }

  /// What the zip's directory lists, read however its entries are stored:
  /// a manifest marks a backup, worth staging; without one, its layout tells
  /// a copy for other apps from anything else. A zip with no directory to
  /// list is unreadable; a zip64 one is foreign, since this app never writes
  /// zip64.
  Future<ZipContents> _peekContents(File file) async {
    try {
      final names = await StoredZipReader.listNames(file);
      if (names.contains('manifest.json')) return ZipContents.backup;
      return looksLikeExport(names) ? ZipContents.export : ZipContents.foreign;
    } on StoredZipException catch (e) {
      return e.error == StoredZipError.unsupported ? ZipContents.foreign : ZipContents.unreadable;
    } catch (_) {
      return ZipContents.unreadable;
    }
  }

  /// Best-effort delete of a picked archive copy once its flow has resolved.
  /// The picker hands out sandbox tmp copies that iOS only purges lazily; a
  /// journal archive can be large, and test-importing must not stack them.
  Future<void> discardPicked(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // tmp is the OS's to reclaim; a survivor costs disk, not correctness.
    }
  }

  /// The pre-adoption half: unseals when sealed, parses everything strictly,
  /// stages the audio and plans the merge, writing nothing outside a fresh
  /// staging directory the handle owns until [discard]. On any throw the
  /// staging is already gone and the journal provably unchanged.
  Future<StagedImport> stage(String path, {String? passphrase}) async {
    _staging.begin();
    try {
      final staging = await Directory.systemTemp.createTemp('import-');
      _staging.register(staging.path);
      try {
        final parsed = await _stagePayload(path, passphrase, staging);
        final entries = await _transcription.planImportedEntries(parsed.entries);
        final reflections = _reflections.planImportedReflections(parsed.reflections);
        final plan = entries.withReflections(
          visible: reflections.visible,
          state: reflections.state,
        );
        return StagedImport._(staging, parsed.entries, parsed.reflections, plan);
      } catch (_) {
        await _removeStaging(staging);
        rethrow;
      }
    } finally {
      _staging.end();
    }
  }

  /// Merges a staged archive into the journal. Anything escaping here broke
  /// with adoption already writing, so the journal may have changed. Safe to
  /// call again on the same handle after such a failure: settled items are
  /// left alone, files an earlier pass moved in are reused, and the entry
  /// counts cover the whole restore ([StagedImport.adoptedSoFar] holds them
  /// after a throw too). The sweeps stand down from the first call until
  /// [discard]. [onProgress] hears (done, total) entries.
  Future<ImportSummary> adopt(
    StagedImport staged, {
    void Function(int done, int total)? onProgress,
  }) async {
    if (staged._discarded) throw StateError('a discarded import cannot be adopted');
    if (staged._adopting != null) throw StateError('this import is already adopting');
    staged._hold ??= _transcription.holdSweeps();
    final run = Completer<void>();
    staged._adopting = run.future;
    try {
      await _transcription.adoptImportedEntries(
        staged._entries,
        ledger: staged._ledger,
        onProgress: onProgress,
      );
      staged._entriesFinished = true;
      await _reflections.adoptImportedReflections(
        staged._reflections,
        onLanded: () => staged._reflectionsUpdated++,
      );
      return staged.adoptedSoFar;
    } finally {
      staged._adopting = null;
      run.complete();
    }
  }

  /// Deletes the handle's staging, and what an unfinished restore moved in
  /// without saving a record for, then lets the sweep run again. Idempotent,
  /// never throws, and safe while an [adopt] on the handle runs: it waits for
  /// that pass to return.
  Future<void> discard(StagedImport staged) async {
    if (staged._discarded) return;
    staged._discarded = true;
    await staged._adopting;
    try {
      await _transcription.abandonImport(staged._ledger);
    } catch (_) {
      // What survives is recovered as an orphan, visible rather than lost.
    }
    staged._hold?.release();
    await _removeStaging(staged._directory);
  }

  Future<void> _removeStaging(Directory staging) async {
    // Cleanup must never turn a finished operation into a failure: a
    // leftover directory is exactly what the launch sweep exists for.
    try {
      if (await staging.exists()) await staging.delete(recursive: true);
    } catch (_) {}
    _staging.release(staging.path);
  }

  /// The pre-adoption half of an import: protect the staging dir, sniff, unseal
  /// when sealed, parse and stage. Nothing here may write outside [staging].
  Future<_ParsedPayload> _stagePayload(String path, String? passphrase, Directory staging) async {
    try {
      await _share.protect(staging.path);
    } catch (_) {
      // Best-effort: a plaintext journal briefly staged here deserves the
      // same protection class as a shared file, but a failure to apply it
      // must not block an import the user already started.
    }
    final source = File(path);
    final payload = switch (await sniffArchive(source)) {
      ArchiveKind.plainZip => source,
      ArchiveKind.sealed => await _unseal(source, passphrase, staging),
      ArchiveKind.unknown => throw const ArchiveException(
        ArchiveError.malformed,
        'not an opentranscribe archive',
      ),
    };
    final parsed = await _parsePayload(payload, staging);
    if (payload.path != source.path) {
      // Adoption needs only the parsed records and per-entry audio; a
      // plaintext copy of the journal must not wait in tmp for the go-ahead.
      try {
        await payload.delete();
      } catch (_) {}
    }
    return parsed;
  }

  Future<File> _unseal(File source, String? passphrase, Directory staging) async {
    if (passphrase == null) {
      throw ArgumentError('a sealed archive needs its passphrase');
    }
    final payload = File('${staging.path}/payload.zip');
    await openArchiveFile(container: source, target: payload, passphrase: passphrase);
    return payload;
  }

  /// Parses the payload strictly: manifest, every entry record, every
  /// reflection, and every referenced audio file staged out of the zip. Any
  /// failure aborts the whole import; a partial restore is worse than a
  /// clear error. An entry whose audio the archive does not carry lands
  /// transcript-only NOW, because [TranscriptionService.healDanglingAudio]
  /// only repairs transcribed entries and an untranscribed record pointing
  /// at nothing would stay broken forever.
  Future<_ParsedPayload> _parsePayload(File payload, Directory staging) async {
    // Every read is inside the catch, not just the open: a CRC mismatch or a
    // truncated entry surfaces mid-parse, and escaping as a raw
    // StoredZipException would read as a half-written journal.
    try {
      return await _readPayload(payload, staging);
    } on StoredZipException catch (e) {
      throw ArchiveException(switch (e.error) {
        StoredZipError.unsupported => ArchiveError.unsupportedZip,
        StoredZipError.malformed || StoredZipError.tooLarge => ArchiveError.malformed,
      }, e.message);
    }
  }

  Future<_ParsedPayload> _readPayload(File payload, Directory staging) async {
    final zip = await StoredZipReader.open(payload);
    try {
      final paths = zip.paths.toSet();
      if (!paths.contains('manifest.json')) {
        throw const ArchiveException(ArchiveError.malformed, 'archive manifest missing');
      }
      final manifest = ArchiveManifest.fromJson(_decodeJson(await zip.readBytes('manifest.json')));
      final audioDir = Directory('${staging.path}/audio');
      await audioDir.create();
      final entries = <StagedImportEntry>[];
      for (final entryPath in paths.where((p) => p.startsWith('entries/'))) {
        var entry = _parseEntry(await zip.readBytes(entryPath));
        File? stagedAudio;
        final audioName = entry.audioPath;
        if (audioName != null) {
          if (audioName.contains('/')) {
            throw const ArchiveException(ArchiveError.malformed, 'entry audio reference damaged');
          }
          final archived = 'audio/$audioName';
          if (paths.contains(archived)) {
            // Staged per ENTRY, not per file: two records may reference one
            // archived recording, and adoption renames its copy away.
            stagedAudio = File('${audioDir.path}/${entries.length}-$audioName');
            await zip.extractToFile(archived, stagedAudio);
          } else {
            entry = entry.withoutAudio();
          }
        }
        entries.add(StagedImportEntry(entry: entry, stagedAudio: stagedAudio));
      }
      final rows = <Reflection>[
        for (final path in paths.where((p) => p.startsWith('reflections/')))
          _parseReflection(await zip.readBytes(path)),
      ];
      return _ParsedPayload(
        entries: entries,
        reflections: ReflectionArchive(
          rows: rows,
          tombstones: manifest.tombstones,
          floors: manifest.floors,
        ),
      );
    } finally {
      await zip.close();
    }
  }

  Entry _parseEntry(Uint8List bytes) {
    try {
      return Entry.fromJson(_decodeJson(bytes));
    } on ArchiveException {
      rethrow;
    } catch (_) {
      throw const ArchiveException(ArchiveError.malformed, 'entry record damaged');
    }
  }

  Reflection _parseReflection(Uint8List bytes) {
    try {
      return Reflection.fromJson(_decodeJson(bytes));
    } on ArchiveException {
      rethrow;
    } catch (_) {
      throw const ArchiveException(ArchiveError.malformed, 'reflection record damaged');
    }
  }

  Map<String, dynamic> _decodeJson(Uint8List bytes) {
    try {
      return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    } on ArchiveException {
      rethrow;
    } catch (_) {
      throw const ArchiveException(ArchiveError.malformed, 'archive record is not json');
    }
  }
}

final class _ParsedPayload {
  const _ParsedPayload({required this.entries, required this.reflections});

  final List<StagedImportEntry> entries;
  final ReflectionArchive reflections;
}

/// A parsed, staged archive waiting for the user's go-ahead. Owns its staging
/// directory, registered with the sweep, until [ImportService.discard].
final class StagedImport {
  StagedImport._(this._directory, this._entries, this._reflections, this.plan);

  /// What adopting would do to the journal as it stood when staged.
  final ImportPlan plan;

  /// What adoption has done so far across every pass, including one that
  /// broke midway.
  ImportSummary get adoptedSoFar => _ledger.result.withReflections(_reflectionsUpdated);

  /// Every entry has been through adoption, so what a pass that broke left
  /// undone is the reflections.
  bool get entriesFinished => _entriesFinished;

  final Directory _directory;
  final List<StagedImportEntry> _entries;
  final ReflectionArchive _reflections;
  final AdoptLedger _ledger = AdoptLedger();

  /// Summed over every pass, so one that broke partway keeps its count.
  int _reflectionsUpdated = 0;
  bool _entriesFinished = false;
  SweepHold? _hold;
  Future<void>? _adopting;
  bool _discarded = false;
}

/// What a plain zip's directory lists: a manifest ([backup]), none in a zip
/// laid out like one of the app's own copies for other apps ([export]) or
/// like anything else ([foreign]), or no directory to list ([unreadable]).
enum ZipContents { backup, export, foreign, unreadable }

/// Whether a manifest-free zip is laid out like one of the app's own copies
/// for other apps: notes at the top or under entries/, or a website page at
/// the top (the journal's, or a single entry's with its audio).
bool looksLikeExport(Iterable<String> paths) => paths.any(
  (path) =>
      (path.endsWith('.html') && !path.contains('/')) ||
      (path.endsWith('.md') && (!path.contains('/') || path.startsWith('entries/'))),
);

/// What the picked file looks like before any import work: its kind for the
/// passphrase decision, its name and size to show, and for a plain zip what
/// its directory listing shows.
@immutable
final class ImportProbe {
  const ImportProbe({
    required this.kind,
    required this.fileName,
    required this.sizeBytes,
    this.contents,
  });

  final ArchiveKind kind;
  final String fileName;
  final int sizeBytes;

  /// Null for anything but a plain zip; a sealed archive cannot be listed
  /// before its passphrase.
  final ZipContents? contents;

  @override
  bool operator ==(Object other) =>
      other is ImportProbe &&
      other.kind == kind &&
      other.fileName == fileName &&
      other.sizeBytes == sizeBytes &&
      other.contents == contents;

  @override
  int get hashCode => Object.hash(kind, fileName, sizeBytes, contents);
}
