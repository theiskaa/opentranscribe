import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/models/reflection.dart';
import 'package:opentranscribe/core/reflect/reflection_engine.dart';
import 'package:opentranscribe/core/reflect/reflection_exception.dart';
import 'package:opentranscribe/core/services/reflection_settings.dart';
import 'package:opentranscribe/core/services/reflection_store.dart';
import 'package:opentranscribe/core/utils/week.dart';

// The collaborators are private (the service owns them) and named parameters
// cannot be private, so initializing formals do not apply.
// ignore_for_file: prefer_initializing_formals

/// Owns the weekly-reflection lifecycle: which week to reflect, gathering its
/// entries, asking the engine, and persisting the result (text or a stored
/// silence). The engine and store stay private here so nothing bypasses the
/// on-device guard or the silence-is-a-result rule.
///
/// The trigger is the foreground: [catchUp] runs at launch and on resume. There
/// is no server and no schedule; a closed week is reflected the next time the
/// app is opened.
///
/// A reflection is an immutable record of the week as it was heard. Deleting
/// source entries afterwards never cascades into the history (an emptied week
/// keeps its text; an explicit [regenerate] of one records an honest silence);
/// the user's per-week [deleteReflection] is the only eraser.
class ReflectionService {
  ReflectionService({
    required ReflectionEngine engine,
    required ReflectionStore store,
    required ReflectionSettings settings,
    required List<Entry> Function() entries,
    required String Function() language,
    DateTime Function()? clock,
    DateTime Function(DateTime)? weekOf,
    Duration? reflectTimeout,
  }) : _engine = engine,
       _store = store,
       _settings = settings,
       _entries = entries,
       _language = language,
       _clock = clock ?? DateTime.now,
       _reflectTimeout = reflectTimeout ?? const Duration(minutes: 3),
       // Resolve the week boundary from the app language explicitly, not the
       // ambient Intl locale: the launch catch-up can run before the first
       // frame sets that global, which would bucket weeks against the wrong
       // first-day. Tests inject a fixed [weekOf].
       _weekOf = weekOf ?? ((d) => startOfWeek(d, localeId: language())) {
    // The one rule, enforced in code: reflections never leave the device.
    if (!_engine.onDeviceOnly) {
      throw ArgumentError('ReflectionService requires an on-device engine: ${_engine.id}');
    }
  }

  final ReflectionEngine _engine;
  final ReflectionStore _store;
  final ReflectionSettings _settings;
  final List<Entry> Function() _entries;
  final String Function() _language;
  final DateTime Function() _clock;
  final DateTime Function(DateTime) _weekOf;

  /// Bound on one generation. Without it a hung engine call would hold the
  /// catch-up single-flight, and a regenerate's in-flight marker, until
  /// relaunch; a timeout instead reads as the transient could-not-run.
  final Duration _reflectTimeout;

  /// Soft ceiling on the estimated prompt tokens for one week, safely under the
  /// on-device model's ~4k context window, leaving room for the instructions
  /// and the response. Budgeted in tokens, not characters: a character cap
  /// sized for Latin text sails a CJK week (near one token per character)
  /// straight into a context overflow, a deterministic failure that would be
  /// stored as a false quiet week.
  static const _maxPromptTokens = 2000;

  final StreamController<void> _changed = StreamController<void>.broadcast();

  /// Fires whenever a reflection is written, regenerated, or deleted, so a
  /// surface can refresh its history.
  Stream<void> get reflectionsChanged => _changed.stream;

  /// Single-flights [catchUp]: a resume racing the launch kick must not run twice.
  bool _running = false;

  /// Reflects every closed, unreflected week that has material, newest week
  /// first, never reaching below the no-backfill floor. Cheap and safe to call
  /// often. A no-op when reflections are disabled or the on-device model is
  /// unavailable: no generation, no error, nothing surfaced. Never throws.
  Future<void> catchUp() async {
    if (_running || !_settings.enabled) return;
    // Claimed BEFORE the availability await: a resume racing the launch kick
    // must not both slip past the guard while the first is probing.
    _running = true;
    try {
      // Recorded before the availability gate: the floor marks when the
      // FEATURE first ran, not when the model first answered.
      final floor = await _ensureFloor();
      if (floor == null) return;
      // Availability is probed live, so enabling the model mid-life is
      // picked up on the next open rather than needing a relaunch.
      final availability = await _engine.availability();
      if (!availability.isAvailable) return;

      final currentWeek = currentWeekStart();
      final byWeek = _entriesByWeek();
      final weeks = byWeek.keys.where((w) => w.isBefore(currentWeek)).toList()
        ..sort((a, b) => b.compareTo(a));

      for (final week in weeks) {
        // Disabling mid-run stops the rest of the backlog, not just the next open.
        if (!_settings.enabled) break;
        // No backfill: a week that closed entirely before the feature first
        // ran is history, not a queue. This is also the churn bound: an
        // upgrade with months of older entries reflects nothing from before
        // its first post-floor week.
        if (!weekClearsFloor(week, floor)) continue;
        // Stored rows and tombstones are re-read every iteration, not
        // snapshotted before the loop: the generation awaits are long enough
        // for a user regenerate or delete to land, and acting on a stale
        // snapshot would overwrite it.
        //
        // A stored reflection (text OR silence) is done; never re-run. Done is
        // judged by RANGE overlap, not exact key: an app-language change can
        // shift the first-day-of-week, and the shifted candidate must still
        // see the reflection written under the old boundary, or one language
        // switch would re-reflect the whole history into overlapping duplicates.
        if (_covered(week, _store.all())) continue;
        // An erased week stays erased: the user's delete must not be overruled
        // by the next open re-reflecting a week whose entries still exist.
        // Range-matched like the done-check, so a locale shift cannot
        // resurrect around the tombstone.
        if (_tombstoned(week)) continue;
        try {
          await _reflectWeek(week, byWeek[week]!);
        } on ReflectionUnavailable {
          // The MODEL is not usable right now (system-level, transient). Stop
          // and leave the rest unreflected; the next open retries all. A
          // deterministic per-week failure comes back as silence, not this, so
          // it never reaches here to head-of-line-block older weeks.
          break;
        } catch (e) {
          // A one-off per-week failure (e.g. a storage write) must not block
          // the other weeks, nor escape: skip it, it stays eligible.
          if (kDebugMode) debugPrint('reflection: week $week failed: $e');
        }
      }
    } catch (e) {
      // catchUp is fired unawaited from launch and resume, so it must never
      // throw: a failure before the loop (a read) is logged and swallowed.
      if (kDebugMode) debugPrint('reflection: catch-up failed: $e');
    } finally {
      _running = false;
    }
  }

  /// Force-reflects one week in the CURRENT style, replacing any stored result.
  /// The explicit per-week action. Unlike [catchUp] it ignores the enabled flag
  /// (the user asked for this one) and lets a [ReflectionUnavailable] surface, so
  /// the caller can offer a retry instead of it being swallowed.
  Future<void> regenerate(DateTime weekStart) async {
    // Key off the STORED week as-is; do NOT re-bucket through the current
    // locale (an app-language change could shift the boundary and orphan the
    // reflection under a new key). Gather the week's entries by the same 7-day
    // range, so this is locale-independent too.
    final week = dateOnly(weekStart);
    final end = addDays(week, 7);
    final entries = [
      for (final e in _entries())
        if (_dayInWeek(dateOnly(e.createdAt.toLocal()), week, end)) e,
    ];
    await _reflectWeek(week, entries, force: true);
  }

  bool _dayInWeek(DateTime day, DateTime start, DateTime end) =>
      !day.isBefore(start) && day.isBefore(end);

  /// The no-backfill floor, recorded exactly once: the app-language week start
  /// of the day the feature first ran. Null when a record exists but cannot be
  /// parsed; the catch-up then sits the run out, because re-recording at the
  /// current week would permanently orphan the journaled weeks below the true
  /// floor. [regenerate] never checks the floor: it is the user's explicit
  /// per-week ask, so the no-backfill rule deliberately does not apply.
  Future<DateTime?> _ensureFloor() async {
    final stored = _settings.floor;
    if (stored != null) return stored;
    if (_settings.floorRecorded) return null;
    final floor = currentWeekStart();
    await _settings.setFloor(floor);
    return floor;
  }

  /// Whether any of [stored] covers [week]'s 7-day range.
  bool _covered(DateTime week, List<Reflection> stored) =>
      stored.any((r) => weeksOverlap(week, r.weekStart));

  /// Whether a user erasure covers [week]'s 7-day range.
  bool _tombstoned(DateTime week) => _store.deletedWeeks().any((d) => weeksOverlap(week, d));

  /// The stored history, newest week first, for the surfaces. The store itself
  /// stays private so every write goes through this service.
  List<Reflection> history() => _store.all();

  /// Week starts (app-language bucketing) holding at least one entry with
  /// material. An untranscribed-only week is excluded so the pager never
  /// shows a waiting page the catch-up would skip for having nothing to read.
  Set<DateTime> journaledWeekStarts() => {
    for (final e in _entries())
      if (_hasMaterial(e)) _weekOfEntry(e),
  };

  /// The open week's start under the app-language bucketing: the timeline's
  /// ceiling, resolved here so surfaces never re-derive the boundary.
  DateTime currentWeekStart() => _weekOf(dateOnly(_clock()));

  /// The weeks the user erased (tombstones), stored starts as-is.
  List<DateTime> deletedWeeks() => _store.deletedWeeks();

  /// Probes whether the on-device model can run right now. Live, never cached:
  /// enabling the on-device model mid-life must be seen on the next probe.
  Future<ReflectionAvailability> availability() => _engine.availability();

  /// Removes a week's reflection, keyed off the STORED week as-is, exactly like
  /// [regenerate]: re-bucketing through the current locale would miss the record
  /// after a first-day-shifting language change.
  Future<void> deleteReflection(DateTime weekStart) async {
    await _store.delete(dateOnly(weekStart));
    _emitChanged();
  }

  Future<void> _reflectWeek(DateTime week, List<Entry> entries, {bool force = false}) async {
    final inputs = _inputsFor(entries);
    // Nothing transcribed to read. On catch-up, leave the week unreflected so a
    // later transcription can still produce one. On an explicit regenerate, the
    // user asked, so record an honest silence.
    if (inputs.isEmpty && !force) return;

    // Read the style ONCE, before the await, so the persisted voice is the one
    // the text was actually generated with even if a setting changes mid-run.
    final style = _settings.style;
    final erased = _tombstoned(week);
    final text = inputs.isEmpty
        ? null
        : await _engine
              .reflect(entries: inputs, style: style, localeId: _language())
              .timeout(
                _reflectTimeout,
                onTimeout: () => throw const ReflectionUnavailable('generation timed out'),
              );

    // A delete that landed during the generation wins: saving now would clear
    // the tombstone the user just wrote and resurrect the week. A tombstone
    // that predates the run is a regenerate of an erased week, which the user
    // asked for, so that one saves through.
    if (!erased && _tombstoned(week)) return;

    await _store.save(
      Reflection(weekStart: week, generatedAt: _clock(), text: text, voice: style.voice),
    );
    _emitChanged();
  }

  Map<DateTime, List<Entry>> _entriesByWeek() {
    final byWeek = <DateTime, List<Entry>>{};
    for (final e in _entries()) {
      (byWeek[_weekOfEntry(e)] ??= []).add(e);
    }
    return byWeek;
  }

  /// The week an entry belongs to: its LOCAL civil date resolved to the week's
  /// first day. createdAt is stored UTC; a week boundary is a civil/local day.
  DateTime _weekOfEntry(Entry e) => _weekOf(dateOnly(e.createdAt.toLocal()));

  /// The one material test, shared by generation and the surfaces: an entry
  /// counts only once it carries transcribed text.
  static bool _hasMaterial(Entry e) => e.transcript?.fullText.trim().isNotEmpty ?? false;

  /// The week's entries as the engine sees them: chronological, material only,
  /// with the weekday each was recorded on; the whole is capped to
  /// [_maxPromptTokens].
  List<ReflectionEntryInput> _inputsFor(List<Entry> entries) {
    final ordered = [...entries]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return _capped([
      for (final e in ordered)
        if (_hasMaterial(e))
          ReflectionEntryInput(
            weekday: e.createdAt.toLocal().weekday,
            text: e.transcript!.fullText.trim(),
            title: e.title,
          ),
    ]);
  }

  /// Keeps the combined transcripts AND titles under [_maxPromptTokens] so a
  /// heavy week cannot overflow the small on-device context window (a
  /// deterministic failure). Every day is kept but trimmed to an equal share,
  /// so the week's shape survives at reduced detail rather than a day being
  /// dropped whole; a title spends from its entry's share, since the prompt
  /// carries both.
  List<ReflectionEntryInput> _capped(List<ReflectionEntryInput> inputs) {
    if (inputs.isEmpty) return inputs;
    final total = inputs.fold<int>(0, (sum, i) => sum + _inputTokens(i));
    if (total <= _maxPromptTokens) return inputs;
    final share = _maxPromptTokens ~/ inputs.length;
    return [
      for (final i in inputs)
        if (_inputTokens(i) <= share)
          i
        else
          ReflectionEntryInput(
            weekday: i.weekday,
            text: _trimToTokens(i.text, math.max(0, share - _titleTokens(i))),
            title: i.title,
          ),
    ];
  }

  static int _titleTokens(ReflectionEntryInput i) =>
      i.title == null ? 0 : _estimatedTokens(i.title!);

  static int _inputTokens(ReflectionEntryInput i) => _estimatedTokens(i.text) + _titleTokens(i);

  /// Estimated quarter-tokens for one code point, so every density shares one
  /// integer budget. The on-device tokenizer runs near one token per character
  /// for CJK ideographs, kana, Hangul, and the space-less South-East Asian
  /// scripts; near two characters per token for the non-Latin alphabetic
  /// scripts; and near four characters per token for everything else.
  static int _runeQuarters(int rune) {
    if ((rune >= 0x0E00 && rune <= 0x0EFF) || // Thai, Lao
        (rune >= 0x1000 && rune <= 0x109F) || // Myanmar
        (rune >= 0x1780 && rune <= 0x17FF) || // Khmer
        (rune >= 0x2E80 && rune <= 0x9FFF) ||
        (rune >= 0xAC00 && rune <= 0xD7AF) ||
        (rune >= 0xF900 && rune <= 0xFAFF) ||
        rune >= 0x20000) {
      return 4;
    }
    if ((rune >= 0x0370 && rune <= 0x03FF) || // Greek
        (rune >= 0x0400 && rune <= 0x04FF) || // Cyrillic
        (rune >= 0x0590 && rune <= 0x05FF) || // Hebrew
        (rune >= 0x0600 && rune <= 0x06FF) || // Arabic
        (rune >= 0x0900 && rune <= 0x097F)) {
      // Devanagari
      return 2;
    }
    return 1;
  }

  static int _estimatedTokens(String text) {
    var quarters = 0;
    for (final rune in text.runes) {
      quarters += _runeQuarters(rune);
    }
    return (quarters + 3) ~/ 4;
  }

  /// [text] cut to at most [budget] estimated tokens. Walks code points, so the
  /// cut can never split a surrogate pair into a mangled character.
  static String _trimToTokens(String text, int budget) {
    final quarters = budget * 4;
    var used = 0;
    var end = 0;
    for (final rune in text.runes) {
      used += _runeQuarters(rune);
      if (used > quarters) break;
      end += rune > 0xFFFF ? 2 : 1;
    }
    return text.substring(0, end);
  }

  void _emitChanged() {
    if (!_changed.isClosed) _changed.add(null);
  }

  Future<void> dispose() => _changed.close();
}
