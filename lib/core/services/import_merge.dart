import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:opentranscribe/core/export/file_names.dart';
import 'package:opentranscribe/core/models/entry.dart';

/// One archive entry ready for adoption: the record (its [Entry.audioPath]
/// already the intended bare filename, or null for transcript-only) and the
/// temp-staged audio file to move in, when the archive carried one.
@immutable
final class StagedImportEntry {
  const StagedImportEntry({required this.entry, this.stagedAudio});

  final Entry entry;
  final File? stagedAudio;
}

/// How a staged archive merges into the journal: [added] new ids,
/// [replaced] ids whose stored record differs, [unchanged] ids already
/// identical with nothing to move, and [recordings] ids already identical
/// whose recording is missing here and comes back from the archive.
/// [reflections] counts reflections a reader would see saved or erased;
/// [reflectionState] what only the app keeps (history floors, erasures where
/// no row stands). Renaming the audio file on adoption is not a difference.
@immutable
final class ImportPlan {
  const ImportPlan({
    required this.added,
    required this.replaced,
    required this.unchanged,
    this.recordings = 0,
    this.reflections = 0,
    this.reflectionState = 0,
  });

  final int added;
  final int replaced;
  final int unchanged;
  final int recordings;
  final int reflections;
  final int reflectionState;

  /// Nothing would change at all, seen or kept. Only then is there nothing
  /// to adopt.
  bool get isEmpty => changesNothingSeen && reflectionState == 0;

  /// Nothing a reader would see would change (no entry, recording or
  /// reflection), though the app's own state may still be brought up to
  /// date.
  bool get changesNothingSeen => added + replaced + recordings + reflections == 0;

  ImportPlan withReflections({required int visible, required int state}) => ImportPlan(
    added: added,
    replaced: replaced,
    unchanged: unchanged,
    recordings: recordings,
    reflections: visible,
    reflectionState: state,
  );

  @override
  bool operator ==(Object other) =>
      other is ImportPlan &&
      other.added == added &&
      other.replaced == replaced &&
      other.unchanged == unchanged &&
      other.recordings == recordings &&
      other.reflections == reflections &&
      other.reflectionState == reflectionState;

  @override
  int get hashCode =>
      Object.hash(added, replaced, unchanged, recordings, reflections, reflectionState);
}

/// What an import did to the journal: the counts its result line tells.
@immutable
final class ImportSummary {
  const ImportSummary({
    required this.entriesAdded,
    required this.entriesReplaced,
    this.recordingsBroughtBack = 0,
    this.reflectionsUpdated = 0,
  });

  final int entriesAdded;
  final int entriesReplaced;

  /// Identical entries whose missing recording came back from the archive.
  final int recordingsBroughtBack;

  /// Reflections saved or erased, across every pass.
  final int reflectionsUpdated;

  ImportSummary withReflections(int updated) => ImportSummary(
    entriesAdded: entriesAdded,
    entriesReplaced: entriesReplaced,
    recordingsBroughtBack: recordingsBroughtBack,
    reflectionsUpdated: updated,
  );

  @override
  bool operator ==(Object other) =>
      other is ImportSummary &&
      other.entriesAdded == entriesAdded &&
      other.entriesReplaced == entriesReplaced &&
      other.recordingsBroughtBack == recordingsBroughtBack &&
      other.reflectionsUpdated == reflectionsUpdated;

  @override
  int get hashCode =>
      Object.hash(entriesAdded, entriesReplaced, recordingsBroughtBack, reflectionsUpdated);
}

/// What one staged item does on adoption, decided before any write.
@immutable
final class AdoptStep {
  const AdoptStep(this.record, this.moveAs);

  /// The record adoption saves; null leaves the stored record as it is.
  final Entry? record;

  /// The basename the staged recording moves in under; null when nothing
  /// moves.
  final String? moveAs;
}

/// Basename to owning entry id, for the records in [stored].
Map<String, String> audioOwners(Iterable<Entry> stored) => {
  for (final e in stored)
    if (e.audioPath != null) baseName(e.audioPath!): e.id,
};

/// The prefix of every name adoption mints for a restored recording, so a
/// later import can tell an earlier import's rename from a recording the
/// entry has since moved to.
const importAudioPrefix = 'otr-import-';

/// Decides one staged item against the journal as it stands, claiming in
/// [owners] any name it moves a file in under or reuses from [landed].
/// Filenames are not identity, ids are: a basename owned by another entry,
/// or a file on disk nobody owns, sends the audio under a [mint]ed name. A
/// name the stored record itself references is its own too, whatever
/// [owners] says: [owners] keeps one id per name, so of two records sharing a
/// recording only one is listed, and the other would otherwise mint a copy
/// and read as replaced depending on store order. [landed] is the name an
/// earlier pass already moved this item's file in under.
AdoptStep adoptStepFor(
  StagedImportEntry item, {
  required Entry? existing,
  required Map<String, String> owners,
  required bool Function(String name) onDisk,
  required bool Function(File staged) stagedExists,
  required String Function() mint,
  String? landed,
}) {
  final entry = item.entry;
  final staged = item.stagedAudio;
  if (staged == null || entry.audioPath == null) return AdoptStep(entry, null);
  final original = baseName(entry.audioPath!);
  if (landed != null) {
    final owner = owners[landed];
    if ((owner == null || _owns(owners, landed, entry, existing)) && onDisk(landed)) {
      owners[landed] = entry.id;
      return AdoptStep(_named(entry, original, landed), null);
    }
    return AdoptStep(_withoutAudio(entry, existing), null);
  }
  final name = _nameRestoredAudio(entry, owners, existing, onDisk) ?? mint();
  final named = _named(entry, original, name);
  if (_owns(owners, name, entry, existing) && onDisk(name)) return AdoptStep(named, null);
  if (!stagedExists(staged)) return AdoptStep(_withoutAudio(entry, existing), null);
  owners[name] = entry.id;
  return AdoptStep(named, name);
}

/// The basename [entry]'s restored audio files under, or null when a fresh
/// one must be minted.
String? _nameRestoredAudio(
  Entry entry,
  Map<String, String> owners,
  Entry? existing,
  bool Function(String name) onDisk,
) {
  final original = baseName(entry.audioPath!);
  if (_owns(owners, original, entry, existing)) return original;
  final adopted = existing?.audioPath;
  final renamed = adopted == null ? null : baseName(adopted);
  final sameRecord = renamed != null && existing == entry.withAudioPath(renamed);
  // An earlier import's minted name stands once the original frees up, so a
  // re-import stays a no-op and never moves back to it.
  if (sameRecord && renamed.startsWith(importAudioPrefix)) return renamed;
  if (owners[original] == null && !onDisk(original)) return original;
  // Taken or stray: reuse the stored name only for the same record, never a
  // newer recording the entry has since moved to.
  return sameRecord ? renamed : null;
}

/// Whether [entry] may use [name]: [owners] names [entry] for it, or its
/// stored record [existing] already references the file.
bool _owns(Map<String, String> owners, String name, Entry entry, Entry? existing) {
  if (owners[name] == entry.id) return true;
  final stored = existing?.audioPath;
  return stored != null && baseName(stored) == name;
}

/// The basename an overwrite of [existing] by [entry] leaves unreferenced in
/// [records]: adoption deletes that file and frees the name. Null when the
/// new record brings no audio of its own or the old file is still in use.
String? releasedAudio(Entry? existing, Entry entry, Iterable<Entry> records) {
  final oldAudio = existing?.audioPath;
  if (oldAudio == null || entry.audioPath == null) return null;
  final basename = baseName(oldAudio);
  if (basename == baseName(entry.audioPath!)) return null;
  final referenced = records.any((e) => e.audioPath != null && baseName(e.audioPath!) == basename);
  return referenced ? null : basename;
}

/// What adopting [staged] into [stored] would do, through the same
/// [adoptStepFor] and [releasedAudio] adoption runs, assuming every move and
/// delete succeeds. [onDisk] answers for the recordings directory as it is.
ImportPlan planAdoption(
  List<StagedImportEntry> staged,
  Iterable<Entry> stored, {
  bool Function(String name)? onDisk,
  bool Function(File staged)? stagedExists,
}) {
  final records = {for (final e in stored) e.id: e};
  final owners = audioOwners(records.values);
  final moved = <String>{};
  final gone = <String>{};
  bool disk(String name) =>
      moved.contains(name) || (!gone.contains(name) && (onDisk?.call(name) ?? false));
  var added = 0;
  var replaced = 0;
  var unchanged = 0;
  var recordings = 0;
  for (var i = 0; i < staged.length; i++) {
    final item = staged[i];
    final existing = records[item.entry.id];
    final step = adoptStepFor(
      item,
      existing: existing,
      owners: owners,
      onDisk: disk,
      stagedExists: stagedExists ?? (_) => true,
      // NUL never occurs in a real basename, so this stands in for a fresh
      // name without colliding with anything.
      mint: () => '\u0000$i',
    );
    final moveAs = step.moveAs;
    if (moveAs != null) moved.add(moveAs);
    final record = step.record;
    if (record == null || record == existing) {
      moveAs == null ? unchanged++ : recordings++;
      continue;
    }
    records[record.id] = record;
    existing == null ? added++ : replaced++;
    final released = releasedAudio(existing, record, records.values);
    if (released != null) {
      owners.remove(released);
      moved.remove(released);
      gone.add(released);
    }
  }
  return ImportPlan(added: added, replaced: replaced, unchanged: unchanged, recordings: recordings);
}

/// What earlier adoption passes over one staged list already did, keyed by
/// position in that list. Only meaningful when every pass is handed the same
/// list.
final class AdoptLedger {
  final Map<int, String> _landed = {};
  final Map<int, _Settled> _settled = {};

  bool isSettled(int index) => _settled.containsKey(index);

  String? landedAt(int index) => _landed[index];

  void land(int index, String name) => _landed[index] = name;

  /// Records what the restore did to one item: an add or a replace of
  /// [existing] when [saved] is set; when it is null, nothing, or only its
  /// recording brought back when this step [moved] a file in, the plan's own
  /// rule. A file an earlier pass moved, gone by now, is no recording back.
  void settle(int index, {required Entry? existing, required Entry? saved, bool moved = false}) =>
      _settled[index] = switch (saved) {
        null => moved ? _Settled.recording : _Settled.unchanged,
        _ when existing == null => _Settled.added,
        _ => _Settled.replaced,
      };

  /// Files a pass moved in for items it never settled: no record was saved
  /// for them yet.
  Iterable<String> get unsettledLandings =>
      _landed.entries.where((l) => !_settled.containsKey(l.key)).map((l) => l.value);

  /// The whole restore so far, across every pass over the list.
  ImportSummary get result => ImportSummary(
    entriesAdded: _settled.values.where((o) => o == _Settled.added).length,
    entriesReplaced: _settled.values.where((o) => o == _Settled.replaced).length,
    recordingsBroughtBack: _settled.values.where((o) => o == _Settled.recording).length,
  );
}

enum _Settled { added, replaced, unchanged, recording }

Entry _named(Entry entry, String original, String name) =>
    name == original ? entry : entry.withAudioPath(name);

/// A stored record keeps what it has rather than pairing the archive's words
/// with whatever recording it holds now; a new record lands transcript-only.
Entry? _withoutAudio(Entry entry, Entry? existing) =>
    existing == null ? entry.withoutAudio() : null;
