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
import 'package:opentranscribe/core/services/reflection_service.dart';
import 'package:opentranscribe/core/services/transcription_service.dart';

/// Restores a native archive into the journal: pick, sniff, decrypt when
/// sealed, parse EVERYTHING strictly, stage audio, then adopt through the
/// lifecycle owners. All-validate-before-any-write: until adoption starts,
/// nothing outside a temp staging directory is touched, so a failed decrypt
/// or a malformed archive provably changes nothing on disk. Merge is by
/// entry id and idempotent. Every archive failure surfaces as
/// [ArchiveException]; three carve-outs are honest exceptions to that: a
/// missing passphrase for a sealed archive is a caller error (ArgumentError;
/// the UI probes first), a disk failure once adoption is already writing
/// surfaces as the underlying FileSystemException, and any other escape
/// before adoption starts is wrapped as [ImportAbortedException], the
/// provably-nothing-changed failure. That classification leans on adoption
/// never throwing ArchiveException or ArgumentError itself.
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
  /// size, and (for a plain archive) the manifest counts the confirm shows.
  Future<ImportProbe> probe(String path) async {
    final file = File(path);
    final kind = await sniffArchive(file);
    return ImportProbe(
      kind: kind,
      fileName: baseName(path),
      sizeBytes: await file.length(),
      counts: kind == ArchiveKind.plainZip ? await _peekCounts(file) : null,
    );
  }

  /// Real manifests are a few hundred bytes; a crafted zip may declare one
  /// spanning the whole file, and a probe must stay cheap.
  static const _maxPeekedManifestBytes = 1 << 20;

  /// Best-effort: null when no readable manifest can be peeked cheaply; a
  /// damaged archive fails later with its own copy.
  Future<ArchiveCounts?> _peekCounts(File file) async {
    try {
      final zip = await StoredZipReader.open(file);
      try {
        if (!zip.paths.contains('manifest.json')) return null;
        if (zip.sizeOf('manifest.json') > _maxPeekedManifestBytes) return null;
        return ArchiveManifest.fromJson(_decodeJson(await zip.readBytes('manifest.json'))).counts;
      } finally {
        await zip.close();
      }
    } catch (_) {
      return null;
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

  /// Runs the whole import. [passphrase] is required for a sealed archive and
  /// ignored for a plain one.
  Future<ImportSummary> importArchive(String path, {String? passphrase}) async {
    _staging.begin();
    try {
      final staging = await _aborting(() => Directory.systemTemp.createTemp('import-'));
      _staging.register(staging.path);
      try {
        final parsed = await _aborting(() => _stagePayload(path, passphrase, staging));
        final adopted = await _transcription.adoptImportedEntries(parsed.entries);
        final reflectionChanges = await _reflections.adoptImportedReflections(parsed.reflections);
        return ImportSummary(
          entriesAdded: adopted.added,
          entriesUpdated: adopted.updated,
          entriesUnchanged: adopted.unchanged,
          audioRestored: adopted.audioRestored,
          reflectionChanges: reflectionChanges,
        );
      } finally {
        // Cleanup must never turn a finished operation into a failure: a
        // leftover directory is exactly what the launch sweep exists for.
        try {
          if (await staging.exists()) await staging.delete(recursive: true);
        } catch (_) {}
        _staging.release(staging.path);
      }
    } finally {
      _staging.end();
    }
  }

  /// Wraps a phase that runs before adoption: any escape that is not an
  /// archive or caller error becomes [ImportAbortedException], because
  /// nothing outside staging was written yet and the failure copy must be
  /// able to say so.
  Future<T> _aborting<T>(Future<T> Function() phase) async {
    try {
      return await phase();
    } on ArchiveException {
      rethrow;
    } on ArgumentError {
      rethrow;
    } catch (e, st) {
      Error.throwWithStackTrace(ImportAbortedException(e), st);
    }
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
    return _parsePayload(payload, staging);
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

/// An import that broke before adoption wrote anything: the journal provably
/// did not change, and the copy this drives must not claim a partial restore.
final class ImportAbortedException implements Exception {
  const ImportAbortedException(this.cause);

  final Object cause;

  @override
  String toString() => 'ImportAbortedException($cause)';
}

final class _ParsedPayload {
  const _ParsedPayload({required this.entries, required this.reflections});

  final List<StagedImportEntry> entries;
  final ReflectionArchive reflections;
}

/// What the picked file looks like before any import work: its kind for the
/// passphrase decision, and name, size, and counts for the confirm sheet.
@immutable
final class ImportProbe {
  const ImportProbe({
    required this.kind,
    required this.fileName,
    required this.sizeBytes,
    this.counts,
  });

  final ArchiveKind kind;
  final String fileName;
  final int sizeBytes;

  /// Null for a sealed archive (unreadable before its passphrase) and for a
  /// zip whose manifest could not be peeked.
  final ArchiveCounts? counts;
}

/// What an import actually did. The summary sheet shows the entry counts;
/// [audioRestored] and [reflectionChanges] round out the result for callers
/// that want the whole picture.
@immutable
final class ImportSummary {
  const ImportSummary({
    required this.entriesAdded,
    required this.entriesUpdated,
    required this.entriesUnchanged,
    required this.audioRestored,
    required this.reflectionChanges,
  });

  final int entriesAdded;
  final int entriesUpdated;
  final int entriesUnchanged;
  final int audioRestored;

  /// Rows, tombstones and floors together; not only reflection texts.
  final int reflectionChanges;

  @override
  bool operator ==(Object other) =>
      other is ImportSummary &&
      other.entriesAdded == entriesAdded &&
      other.entriesUpdated == entriesUpdated &&
      other.entriesUnchanged == entriesUnchanged &&
      other.audioRestored == audioRestored &&
      other.reflectionChanges == reflectionChanges;

  @override
  int get hashCode =>
      Object.hash(entriesAdded, entriesUpdated, entriesUnchanged, audioRestored, reflectionChanges);
}
