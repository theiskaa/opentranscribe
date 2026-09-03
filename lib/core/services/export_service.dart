import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:opentranscribe/core/export/archive_crypto.dart';
import 'package:opentranscribe/core/export/archive_manifest.dart';
import 'package:opentranscribe/core/export/file_names.dart';
import 'package:opentranscribe/core/export/journal_exporter.dart';
import 'package:opentranscribe/core/export/share_export.dart';
import 'package:opentranscribe/core/export/staging_registry.dart';
import 'package:opentranscribe/core/export/stored_zip.dart';
import 'package:opentranscribe/core/export/zip_pack.dart';
import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/services/reflection_service.dart';
import 'package:opentranscribe/core/services/transcription_service.dart';

/// What the journal weighs for the Backup screen's intro and confirms.
@immutable
final class JournalMeasure {
  const JournalMeasure({
    required this.entries,
    required this.recordings,
    required this.approxBytes,
  });

  final int entries;
  final int recordings;

  /// Approximate on purpose; see [ExportService.measure].
  final int approxBytes;

  @override
  bool operator ==(Object other) =>
      other is JournalMeasure &&
      other.entries == entries &&
      other.recordings == recordings &&
      other.approxBytes == approxBytes;

  @override
  int get hashCode => Object.hash(entries, recordings, approxBytes);
}

/// Stages export trees and hands them to the share sheet: one entry or the
/// whole journal in a pluggable format, or the whole journal as the native
/// archive (plain zip, or sealed under a passphrase). Read-only with respect
/// to journal state; every output is built under a fresh temp staging
/// directory that is deleted after the share resolves, completed or not.
/// Returns whether the user completed an activity; cancel is false, never an
/// exception. Every path is free: no export asks for the supporter tier.
class ExportService {
  ExportService({
    required this._transcription,
    required this._reflections,
    required Map<String, JournalExporter> exporters,
    required this._share,
    required this._appVersion,
    required this._staging,
    DateTime Function()? clock,
  }) : _exporters = Map.unmodifiable(exporters),
       _clock = clock ?? DateTime.now;

  final TranscriptionService _transcription;
  final ReflectionService _reflections;
  final Map<String, JournalExporter> _exporters;
  final ShareExport _share;
  final Future<String> Function() _appVersion;
  final StagingRegistry _staging;
  final DateTime Function() _clock;

  /// The pack a running whole-journal share is building, while it builds.
  ZipPack? _activePack;

  /// Calls off the pack phase of a running share, if any: the awaiting call
  /// throws [ZipPackAborted] and cleans its staging like any failure. Once
  /// the share sheet is up there is nothing left to cancel.
  void cancelShare() => _activePack?.abort();

  /// Runs [ZipPack] as the one active pack, reporting fractional progress
  /// and, once the pack lands, [onPackDone], so a cancel affordance can
  /// leave the moment there is nothing left to cancel.
  Future<void> _packInto(
    String target,
    List<(String, Uint8List)> bytes,
    List<(String, String)> files,
    void Function(double fraction)? onProgress,
    void Function()? onPackDone,
  ) async {
    final pack = ZipPack(target: target, bytes: bytes, files: files);
    _activePack = pack;
    try {
      await pack.run(
        onProgress: onProgress == null
            ? null
            : (written, total) {
                // A fileless pack is byte adds alone, over in a blink: no
                // fraction is honest and none is reported. Clamped because a
                // source growing mid-pack would otherwise pass 100%.
                if (total > 0) onProgress((written / total).clamp(0.0, 1.0));
              },
      );
    } finally {
      if (identical(_activePack, pack)) _activePack = null;
    }
    onPackDone?.call();
  }

  /// The audio files a journal share stages, as zip path to source path.
  Future<List<(String, String)>> _audioFileEntries(
    List<Entry> entries,
    Map<String, String> audioNames,
  ) async {
    return [
      for (final entry in entries)
        if (audioNames[entry.id] != null)
          ('audio/${audioNames[entry.id]}', await _transcription.resolveAudioPath(entry)),
    ];
  }

  /// Shares one entry in [exporterId]'s format. A single output file with no
  /// audio shares bare (a lone .md shares better than a zip of one); anything
  /// more zips first. [includeAudio] is honored only when the entry still has
  /// its recording.
  Future<bool> shareEntry(
    String entryId, {
    required String exporterId,
    required bool includeAudio,
    required ExportStrings strings,
  }) async {
    final entry = _transcription.entries().firstWhere(
      (e) => e.id == entryId,
      orElse: () => throw ArgumentError.value(entryId, 'entryId', 'unknown entry'),
    );
    final exporter = _exporter(exporterId);
    final resolvedAudio = includeAudio && entry.hasAudio
        ? await _transcription.resolveAudioPath(entry)
        : null;
    // A vanished file exports transcript-only, like the journal paths do.
    final withAudio = resolvedAudio != null && File(resolvedAudio).existsSync();
    final audioName = withAudio ? baseName(entry.audioPath!) : null;
    final exportEntry = ExportEntry(entry: entry, audioRelativePath: audioName);
    final files = exporter.exportEntry(exportEntry, await _context(strings));
    return _stage((staging) async {
      if (files.length == 1 && !withAudio) {
        final path = '${staging.path}/${baseName(files.single.path)}';
        await File(path).writeAsBytes(files.single.bytes);
        return [path];
      }
      final zipName = '${stripExtension(baseName(files.first.path))}.zip';
      final zip = File('${staging.path}/$zipName');
      final writer = await StoredZipWriter.create(zip);
      try {
        for (final file in files) {
          await writer.addBytes(file.path, file.bytes);
        }
        if (withAudio) {
          await writer.addFile(audioName!, File(resolvedAudio));
        }
        await writer.close();
      } catch (_) {
        await writer.abort();
        rethrow;
      }
      return [zip.path];
    });
  }

  /// What a backup or an audio-included export would hold right now: the
  /// entry count, how many kept recordings would ride along, and roughly
  /// what they weigh (audio file bytes plus transcript lengths; audio
  /// dominates, so the number is honest under a "~" label and never exact).
  Future<JournalMeasure> measure() async {
    final entries = _transcription.entries();
    var recordings = 0;
    var approxBytes = 0;
    for (final entry in entries) {
      approxBytes += entry.readableText?.length ?? 0;
      if (entry.audioPath == null) continue;
      try {
        approxBytes += await File(await _transcription.resolveAudioPath(entry)).length();
        recordings++;
      } catch (_) {
        // A vanished file exports transcript-only; it weighs nothing here.
      }
    }
    return JournalMeasure(
      entries: entries.length,
      recordings: recordings,
      approxBytes: approxBytes,
    );
  }

  /// Shares the whole journal in [exporterId]'s format as one zip: every
  /// entry, the stored reflections, and the kept audio when [includeAudio].
  Future<bool> shareJournal({
    required String exporterId,
    required bool includeAudio,
    required ExportStrings strings,
    void Function(double fraction)? onProgress,
    void Function()? onPackDone,
  }) async {
    final exporter = _exporter(exporterId);
    final entries = _transcription.entries();
    // Left empty when audio is out: every downstream reference keys off this
    // map, so the entries export transcript-only and nothing is staged.
    final audioNames = includeAudio ? await _uniqueAudioNames(entries) : <String, String>{};
    final snapshot = ExportSnapshot(
      entries: [
        for (final entry in entries)
          ExportEntry(
            entry: entry,
            audioRelativePath: audioNames[entry.id] == null
                ? null
                : 'audio/${audioNames[entry.id]}',
          ),
      ],
      reflections: _reflections.archiveSnapshot().rows,
    );
    final files = exporter.exportJournal(snapshot, await _context(strings));
    final audioFiles = await _audioFileEntries(entries, audioNames);
    return _stage((staging) async {
      // The format is in the name: a folder of these is otherwise unreadable
      // once two formats of the same day sit side by side. Sanitized because
      // the id comes from whatever exporter the build registered.
      final slug = sanitizeFileName(exporter.id, fallback: 'export');
      final zip = File('${staging.path}/opentranscribe-export-$slug-${_dateStamp()}.zip');
      await _packInto(
        zip.path,
        [for (final file in files) (file.path, file.bytes)],
        audioFiles,
        onProgress,
        onPackDone,
      );
      return [zip.path];
    });
  }

  /// Shares the native whole-journal archive: the canonical payload zip
  /// (manifest, entry records verbatim, kept audio, reflections), plain when
  /// [passphrase] is null, else sealed into the opaque container.
  Future<bool> shareArchive({
    String? passphrase,
    void Function(double fraction)? onProgress,
    void Function()? onPackDone,
  }) async {
    final entries = _transcription.entries();
    final reflectionArchive = _reflections.archiveSnapshot();
    return _stage((staging) async {
      final payload = File('${staging.path}/payload.zip');
      await _writeArchivePayload(payload, entries, reflectionArchive, onProgress, onPackDone);
      if (passphrase == null) {
        final plain = File('${staging.path}/opentranscribe-backup-${_dateStamp()}.zip');
        await payload.rename(plain.path);
        return [plain.path];
      }
      final sealed = File('${staging.path}/opentranscribe-backup-${_dateStamp()}.otarchive');
      await sealArchiveFile(payload: payload, target: sealed, passphrase: passphrase);
      await payload.delete();
      return [sealed.path];
    });
  }

  Future<void> _writeArchivePayload(
    File target,
    List<Entry> entries,
    ReflectionArchive reflections,
    void Function(double fraction)? onProgress,
    void Function()? onPackDone,
  ) async {
    final audioNames = await _uniqueAudioNames(entries);
    final manifest = ArchiveManifest(
      appVersion: await _appVersion(),
      createdAt: _clock(),
      counts: ArchiveCounts(
        entries: entries.length,
        audio: audioNames.length,
        reflections: reflections.rows.length,
        tombstones: reflections.tombstones.length,
      ),
      tombstones: reflections.tombstones,
      floors: reflections.floors,
    );
    final bytes = <(String, Uint8List)>[
      ('manifest.json', utf8.encode(jsonEncode(manifest.toJson()))),
    ];
    for (final entry in entries) {
      // The record travels verbatim except audioPath, rewritten to the
      // archived basename so import resolves inside the archive, not
      // against whatever this device's recordings directory held.
      var record = entry;
      final audioName = audioNames[entry.id];
      if (audioName != null && entry.audioPath != audioName) {
        record = entry.withAudioPath(audioName);
      }
      if (audioName == null && entry.audioPath != null) {
        record = entry.withoutAudio();
      }
      bytes.add(('entries/${entry.id}.json', utf8.encode(jsonEncode(record.toJson()))));
    }
    for (final reflection in reflections.rows) {
      bytes.add((
        'reflections/${reflection.period.wire}-${reflection.periodKey}.json',
        utf8.encode(jsonEncode(reflection.toJson())),
      ));
    }
    await _packInto(
      target.path,
      bytes,
      await _audioFileEntries(entries, audioNames),
      onProgress,
      onPackDone,
    );
  }

  /// Bare audio names by entry id, uniqued: basenames are UUID-based and
  /// unique in practice, but two legacy absolute paths could collide, and one
  /// overwritten recording in an archive would be silent data loss. Entries
  /// whose audio file is missing are left out (exported transcript-only, and
  /// counted in no manifest), so record, manifest and zip always agree.
  Future<Map<String, String>> _uniqueAudioNames(List<Entry> entries) async {
    final names = <String, String>{};
    final taken = <String>{};
    for (final entry in entries) {
      final path = entry.audioPath;
      if (path == null) continue;
      if (!File(await _transcription.resolveAudioPath(entry)).existsSync()) continue;
      final name = uniqueFileName(baseName(path), taken);
      names[entry.id] = name;
    }
    return names;
  }

  Future<bool> _stage(Future<List<String>> Function(Directory staging) build) async {
    _staging.begin();
    try {
      final staging = await Directory.systemTemp.createTemp('export-');
      _staging.register(staging.path);
      try {
        try {
          await _share.protect(staging.path);
        } catch (_) {
          // Best-effort: a plaintext journal briefly staged here deserves the
          // same protection class as a shared file, but a failure to apply it
          // must not block an export the user already asked for.
        }
        return await _share.shareFiles(await build(staging));
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

  Future<ExportContext> _context(ExportStrings strings) async =>
      ExportContext(strings: strings, generatedAt: _clock(), appVersion: await _appVersion());

  JournalExporter _exporter(String exporterId) {
    final exporter = _exporters[exporterId];
    if (exporter == null) throw ArgumentError.value(exporterId, 'exporterId', 'unknown exporter');
    return exporter;
  }

  String _dateStamp() {
    final now = _clock().toLocal();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }
}
