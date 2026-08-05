import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/models/reflection.dart';
import 'package:opentranscribe/core/reflect/reflection_engine.dart';
import 'package:opentranscribe/core/reflect/reflection_exception.dart';
import 'package:opentranscribe/core/reflect/reflection_period.dart';
import 'package:opentranscribe/core/services/reflection_settings.dart';
import 'package:opentranscribe/core/services/reflection_store.dart';
import 'package:opentranscribe/core/utils/week.dart';

// The collaborators are private (the service owns them) and named parameters
// cannot be private, so initializing formals do not apply.
// ignore_for_file: prefer_initializing_formals

/// Owns the reflection lifecycle across every enabled period: which period to
/// reflect, gathering its entries, asking the engine, and persisting the result
/// (text or a stored silence). The engine and store stay private here so
/// nothing bypasses the on-device guard or the silence-is-a-result rule. Each
/// period is an independent stream with its own enable flag, style, and floor.
///
/// The trigger is the foreground: [catchUp] runs at launch and on resume. There
/// is no server and no schedule; a closed period is reflected the next time the
/// app is opened.
///
/// A reflection is an immutable record of the period as it was heard. Deleting
/// source entries afterwards never cascades into the history (an emptied period
/// keeps its text; an explicit [regenerate] of one records an honest silence);
/// the user's per-period [deleteReflection] is the only eraser.
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
       // first-day. Daily and monthly boundaries are locale-independent and
       // resolved directly. Tests inject a fixed [weekOf].
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

  final StreamController<void> _changed = StreamController<void>.broadcast();

  /// Fires whenever a reflection is written, regenerated, or deleted, so a
  /// surface can refresh its history.
  Stream<void> get reflectionsChanged => _changed.stream;

  /// Single-flights [catchUp]: a resume racing the launch kick must not run
  /// twice. A call landing mid-flight is coalesced into one trailing pass, so
  /// a backlog request that raced a running catch-up is still covered by the
  /// caller's await instead of silently no-oping.
  bool _running = false;
  bool _pending = false;

  /// Reflects every closed, unreflected period that has material, for each
  /// enabled period, newest first, never reaching below that period's
  /// no-backfill floor. Cheap and safe to call often. A no-op when no period is
  /// enabled or the on-device model is unavailable: no generation, no error,
  /// nothing surfaced. Never throws.
  Future<void> catchUp() async {
    if (!_settings.anyEnabled) return;
    if (_running) {
      _pending = true;
      return;
    }
    // Claimed BEFORE the availability await: a resume racing the launch kick
    // must not both slip past the guard while the first is probing.
    _running = true;
    try {
      do {
        _pending = false;
        for (final period in ReflectionPeriod.values) {
          if (!_settings.enabledFor(period)) continue;
          try {
            await _catchUpPeriod(period);
          } catch (e) {
            // One period's setup failure (a floor write, say) must not deny the
            // others their pass this open. catchUp is fired unawaited from launch
            // and resume, so it must never throw either.
            if (kDebugMode) debugPrint('reflection: ${period.wire} catch-up failed: $e');
          }
        }
      } while (_pending);
    } finally {
      _running = false;
    }
  }

  /// Reflects the WHOLE journal, not just each period's floor-forward stream:
  /// lowers every enabled period's no-backfill floor to its earliest entry
  /// with material, then runs the ordinary [catchUp]. The user's explicit
  /// "reflect on my history" ask, for content that predates the feature (or a
  /// period only just enabled). Fills every closed period that has material
  /// and is neither already reflected nor erased; existing reflections and
  /// tombstones stand. Idempotent, and cheap once the backlog is drained.
  ///
  /// Emits a change once the floors drop, before generating, so the surface
  /// shows the whole backlog as waiting pages at once and then fills them in.
  Future<void> reflectBacklog() async {
    var lowered = false;
    for (final period in ReflectionPeriod.values) {
      if (!_settings.enabledFor(period)) continue;
      final earliest = _earliestMaterialStart(period);
      if (earliest == null) continue;
      final floor = _settings.floorFor(period);
      if (floor == null || earliest.isBefore(floor)) {
        await _settings.setFloorFor(period, earliest);
        lowered = true;
      }
    }
    if (lowered) _emitChanged();
    // A launch/resume catch-up still in flight coalesces this call into one
    // trailing pass, which this await covers, so the backlog drains before
    // this method returns rather than waiting for the next open.
    await catchUp();
  }

  /// Whether [reflectBacklog] has anything to do: an enabled period with a
  /// closed, journaled start that holds material and is neither reflected nor
  /// erased. Drives the surface's offer of the action, so it appears only with
  /// a backlog and self-hides once drained.
  bool hasBacklog() {
    final stored = _store.all();
    for (final period in ReflectionPeriod.values) {
      if (!_settings.enabledFor(period)) continue;
      final current = _currentStart(period);
      for (final start in journaledStartsFor(period)) {
        if (!start.isBefore(current)) continue;
        if (_covered(period, start, stored)) continue;
        if (_tombstoned(period, start)) continue;
        return true;
      }
    }
    return false;
  }

  /// The earliest [period] start holding an entry with material, or null when
  /// the period has none.
  DateTime? _earliestMaterialStart(ReflectionPeriod period) {
    DateTime? earliest;
    for (final start in journaledStartsFor(period)) {
      if (earliest == null || start.isBefore(earliest)) earliest = start;
    }
    return earliest;
  }

  Future<void> _catchUpPeriod(ReflectionPeriod period) async {
    // Recorded before the availability gate: the floor marks when this period
    // first ran, not when the model first answered.
    final floor = await _ensureFloor(period);
    if (floor == null) return;
    // Availability is probed live, so enabling the model mid-life is picked up
    // on the next open rather than needing a relaunch.
    final availability = await _engine.availability();
    if (!availability.isAvailable) return;

    final current = _currentStart(period);
    final byStart = _entriesByPeriod(period);
    final starts = byStart.keys.where((s) => s.isBefore(current)).toList()
      ..sort((a, b) => b.compareTo(a));

    for (final start in starts) {
      // Disabling mid-run stops the rest of this period's backlog.
      if (!_settings.enabledFor(period)) break;
      // No backfill: a period that closed entirely before this period first ran
      // is history, not a queue. This is also the churn bound.
      if (!clearsFloor(start, period, floor)) continue;
      // Stored rows and tombstones are re-read every iteration, not snapshotted
      // before the loop: the generation awaits are long enough for a user
      // regenerate or delete to land, and acting on a stale snapshot would
      // overwrite it.
      //
      // A stored reflection (text OR silence) is done; never re-run. Done is
      // judged by RANGE overlap, not exact key: an app-language change can shift
      // the first-day-of-week, and the shifted candidate must still see the
      // reflection written under the old boundary, or one language switch would
      // re-reflect the whole history into overlapping duplicates.
      if (_covered(period, start, _store.all())) continue;
      // An erased period stays erased: the user's delete must not be overruled
      // by the next open re-reflecting a period whose entries still exist.
      if (_tombstoned(period, start)) continue;
      try {
        await _reflectPeriod(period, start, byStart[start]!);
      } on ReflectionUnavailable {
        // The MODEL is not usable right now (system-level, transient). Stop and
        // leave the rest unreflected; the next open retries all. A deterministic
        // per-period failure comes back as silence, not this, so it never
        // reaches here to head-of-line-block older periods.
        break;
      } catch (e) {
        // A one-off per-period failure (e.g. a storage write) must not block the
        // other periods, nor escape: skip it, it stays eligible.
        if (kDebugMode) debugPrint('reflection: ${period.wire} $start failed: $e');
      }
    }
  }

  /// Force-reflects one [period] at [start] in that period's CURRENT style,
  /// replacing any stored result. The explicit per-period action. Unlike
  /// [catchUp] it ignores the enabled flag (the user asked for this one) and
  /// lets a [ReflectionUnavailable] surface, so the caller can offer a retry
  /// instead of it being swallowed.
  Future<void> regenerate(
    DateTime start, {
    ReflectionPeriod period = ReflectionPeriod.weekly,
  }) async {
    // Key off the STORED start as-is; do NOT re-bucket through the current
    // locale (an app-language change could shift the boundary and orphan the
    // reflection under a new key). Gather the entries by the same range, so this
    // is locale-independent too.
    final periodStart = dateOnly(start);
    final end = nextPeriodStart(periodStart, period);
    final entries = [
      for (final e in _entries())
        if (_inRange(dateOnly(e.createdAt.toLocal()), periodStart, end)) e,
    ];
    await _reflectPeriod(period, periodStart, entries, force: true);
  }

  bool _inRange(DateTime day, DateTime start, DateTime end) =>
      !day.isBefore(start) && day.isBefore(end);

  /// [period]'s no-backfill floor, recorded exactly once: the period start of
  /// the day it first ran. Null when a record exists but cannot be parsed; the
  /// catch-up then sits the period out, because re-recording at the current
  /// period would permanently orphan the journaled periods below the true floor.
  /// [regenerate] never checks the floor: it is the user's explicit per-period
  /// ask, so the no-backfill rule deliberately does not apply.
  Future<DateTime?> _ensureFloor(ReflectionPeriod period) async {
    final stored = _settings.floorFor(period);
    if (stored != null) return stored;
    if (_settings.floorRecordedFor(period)) return null;
    final floor = _currentStart(period);
    await _settings.setFloorFor(period, floor);
    return floor;
  }

  /// Whether any of [stored] for [period] covers [start]'s range.
  bool _covered(ReflectionPeriod period, DateTime start, List<Reflection> stored) =>
      stored.any((r) => r.period == period && periodsOverlap(start, r.periodStart, period));

  /// Whether a user erasure of [period] covers [start]'s range.
  bool _tombstoned(ReflectionPeriod period, DateTime start) =>
      _store.deletedRefs().any((d) => d.period == period && periodsOverlap(start, d.start, period));

  /// [period]'s stored history, newest first, for the surfaces. The store stays
  /// private so every write goes through this service.
  List<Reflection> historyFor(ReflectionPeriod period) => [
    for (final r in _store.all())
      if (r.period == period) r,
  ];

  /// Every period's stored history, newest first, from ONE store read: the
  /// surface that shows more than one period at a time (the reflections cubit)
  /// groups here instead of scanning the store once per period.
  Map<ReflectionPeriod, List<Reflection>> historiesByPeriod() {
    final byPeriod = {for (final p in ReflectionPeriod.values) p: <Reflection>[]};
    for (final r in _store.all()) {
      byPeriod[r.period]!.add(r);
    }
    return byPeriod;
  }

  /// [period] starts holding at least one entry with material. An
  /// untranscribed-only period is excluded so the pager never shows a waiting
  /// page the catch-up would skip for having nothing to read.
  Set<DateTime> journaledStartsFor(ReflectionPeriod period) => {
    for (final e in _entries())
      if (_hasMaterial(e)) _startOfEntry(period, e),
  };

  /// The open [period]'s start: the timeline's ceiling, resolved here so
  /// surfaces never re-derive the boundary.
  DateTime currentStartFor(ReflectionPeriod period) => _currentStart(period);

  /// The [period] starts the user erased (tombstones), stored starts as-is.
  List<DateTime> deletedStartsFor(ReflectionPeriod period) => [
    for (final ref in _store.deletedRefs())
      if (ref.period == period) ref.start,
  ];

  /// Probes whether the on-device model can run right now. Live, never cached:
  /// enabling the on-device model mid-life must be seen on the next probe.
  Future<ReflectionAvailability> availability() => _engine.availability();

  /// Removes a [period]'s reflection at [start], keyed off the STORED start
  /// as-is, exactly like [regenerate]: re-bucketing through the current locale
  /// would miss the record after a first-day-shifting language change.
  Future<void> deleteReflection(
    DateTime start, {
    ReflectionPeriod period = ReflectionPeriod.weekly,
  }) async {
    await _store.delete(dateOnly(start), period: period);
    _emitChanged();
  }

  Future<void> _reflectPeriod(
    ReflectionPeriod period,
    DateTime start,
    List<Entry> entries, {
    bool force = false,
  }) async {
    final inputs = _inputsFor(period, entries);
    // Nothing transcribed to read. On catch-up, leave the period unreflected so
    // a later transcription can still produce one. On an explicit regenerate,
    // the user asked, so record an honest silence.
    if (inputs.isEmpty && !force) return;

    // Read the style ONCE, before the await, so the persisted voice is the one
    // the text was actually generated with even if a setting changes mid-run.
    final style = _settings.styleFor(period);
    final erased = _tombstoned(period, start);
    final text = inputs.isEmpty
        ? null
        : await _engine
              .reflect(period: period, entries: inputs, style: style, localeId: _language())
              .timeout(
                _reflectTimeout,
                onTimeout: () => throw const ReflectionUnavailable('generation timed out'),
              );

    // A delete that landed during the generation wins: saving now would clear
    // the tombstone the user just wrote and resurrect the period. A tombstone
    // that predates the run is a regenerate of an erased period, which the user
    // asked for, so that one saves through.
    if (!erased && _tombstoned(period, start)) return;

    await _store.save(
      Reflection(
        period: period,
        periodStart: start,
        generatedAt: _clock(),
        text: text,
        voice: style.voice,
      ),
    );
    _emitChanged();
  }

  Map<DateTime, List<Entry>> _entriesByPeriod(ReflectionPeriod period) {
    final byStart = <DateTime, List<Entry>>{};
    for (final e in _entries()) {
      (byStart[_startOfEntry(period, e)] ??= []).add(e);
    }
    return byStart;
  }

  /// The [period] start an entry belongs to: its LOCAL civil date resolved to
  /// the period's first day. createdAt is stored UTC; a period boundary is a
  /// civil/local day.
  DateTime _startOfEntry(ReflectionPeriod period, Entry e) =>
      _startOf(dateOnly(e.createdAt.toLocal()), period);

  /// The current open period's start: the timeline's ceiling for [period].
  DateTime _currentStart(ReflectionPeriod period) => _startOf(dateOnly(_clock()), period);

  /// The [period] start containing [day]. Weekly routes through the injected
  /// app-language boundary; daily and monthly are locale-independent and share
  /// the one boundary the timeline also resolves through.
  DateTime _startOf(DateTime day, ReflectionPeriod period) =>
      period == ReflectionPeriod.weekly ? _weekOf(day) : startOfPeriod(day, period);

  /// The one material test, shared by generation and the surfaces: an entry
  /// counts only once it carries transcribed text.
  static bool _hasMaterial(Entry e) => e.transcript?.fullText.trim().isNotEmpty ?? false;

  /// The period's entries as the engine sees them: chronological, material only,
  /// each tagged with the civil date it was recorded on; the whole is capped to
  /// the period's token budget.
  List<ReflectionEntryInput> _inputsFor(ReflectionPeriod period, List<Entry> entries) {
    final ordered = [...entries]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return _capped(period, [
      for (final e in ordered)
        if (_hasMaterial(e))
          ReflectionEntryInput(
            date: dateOnly(e.createdAt.toLocal()),
            text: e.transcript!.fullText.trim(),
            title: e.title,
          ),
    ]);
  }

  /// Soft ceiling on the estimated prompt tokens for one [period], safely under
  /// the on-device model's ~4k context window with room for the instructions and
  /// the response. Scaled by how much a period holds: a day is small, a month
  /// several times a week. Budgeted in tokens, not characters: a character cap
  /// sized for Latin text sails a CJK period (near one token per character)
  /// straight into a context overflow, a deterministic failure that would be
  /// stored as a false quiet period. First-draft sizes; tuned on-device.
  static int _maxPromptTokensFor(ReflectionPeriod period) => switch (period) {
    ReflectionPeriod.daily => 800,
    ReflectionPeriod.weekly => 2000,
    ReflectionPeriod.monthly => 3000,
  };

  /// Keeps the combined transcripts AND titles under the period's budget so a
  /// heavy period cannot overflow the small on-device context window (a
  /// deterministic failure). Every entry is kept but trimmed to an equal share,
  /// so the period's shape survives at reduced detail rather than an entry being
  /// dropped whole; a title spends from its entry's share, since the prompt
  /// carries both.
  List<ReflectionEntryInput> _capped(ReflectionPeriod period, List<ReflectionEntryInput> inputs) {
    if (inputs.isEmpty) return inputs;
    final max = _maxPromptTokensFor(period);
    final total = inputs.fold<int>(0, (sum, i) => sum + _inputTokens(i));
    if (total <= max) return inputs;
    final share = max ~/ inputs.length;
    return [
      for (final i in inputs)
        if (_inputTokens(i) <= share)
          i
        else
          ReflectionEntryInput(
            date: i.date,
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
