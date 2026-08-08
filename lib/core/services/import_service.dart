import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:opentranscribe/core/export/archive_codec.dart';
import 'package:opentranscribe/core/export/archive_crypto.dart';
import 'package:opentranscribe/core/export/archive_manifest.dart';
import 'package:opentranscribe/core/export/share_export.dart';
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
/// [ArchiveException]; two carve-outs are honest exceptions to that: a
/// missing passphrase for a sealed archive is a caller error (ArgumentError;
/// the UI probes first), and a disk failure once adoption is already writing
/// surfaces as the underlying FileSystemException.
class ImportService {
  ImportService({required this._transcription, required this._reflections, required this._share});

  final TranscriptionService _transcription;
  final ReflectionService _reflections;
  final ShareExport _share;

  /// Opens the document picker; null when the user cancels.
  Future<String?> pickArchive() => _share.pickArchive();

  /// What the picked file's first bytes say it is, so the UI knows whether to
  /// ask for a passphrase before running the import.
  Future<ArchiveKind> probe(String path) => sniffArchive(File(path));

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
    final staging = await Directory.systemTemp.createTemp('import-');
    try {
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
      if (await staging.exists()) await staging.delete(recursive: true);
    }
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
      throw ArchiveException(
        e.error == StoredZipError.unsupported
            ? ArchiveError.unsupportedZip
            : ArchiveError.malformed,
        e.message,
      );
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

/// What an import actually did, for the summary sheet.
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

  int get entriesImported => entriesAdded + entriesUpdated;

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
