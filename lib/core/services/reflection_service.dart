import 'dart:async';

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
class ReflectionService {
  ReflectionService({
    required ReflectionEngine engine,
    required ReflectionStore store,
    required ReflectionSettings settings,
    required List<Entry> Function() entries,
    required String Function() language,
    DateTime Function()? clock,
    DateTime Function(DateTime)? weekOf,
  }) : _engine = engine,
       _store = store,
       _settings = settings,
       _entries = entries,
       _language = language,
       _clock = clock ?? DateTime.now,
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

  /// Soft ceiling on the transcript characters sent to the model for one week,
  /// safely under the on-device context window, leaving room for the
  /// instructions and the response.
  static const _maxPromptChars = 8000;

  final StreamController<void> _changed = StreamController<void>.broadcast();

  /// Fires whenever a reflection is written, regenerated, or deleted, so a
  /// surface can refresh its history.
  Stream<void> get reflectionsChanged => _changed.stream;

  /// Single-flights [catchUp]: a resume racing the launch kick must not run twice.
  bool _running = false;

  /// Reflects every closed, unreflected week that has material, newest week
  /// first. Cheap and safe to call often. A no-op when reflections are disabled
  /// or Apple Intelligence is unavailable: no generation, no error, nothing
  /// surfaced. Never throws.
  Future<void> catchUp() async {
    if (_running || !_settings.enabled) return;
    // Claimed BEFORE the availability await: a resume racing the launch kick
    // must not both slip past the guard while the first is probing.
    _running = true;
    try {
      // Availability is probed live, so enabling Apple Intelligence mid-life is
      // picked up on the next open rather than needing a relaunch.
      final availability = await _engine.availability();
      if (!availability.isAvailable) return;

      final currentWeek = _weekOf(dateOnly(_clock()));
      final byWeek = _entriesByWeek();
      final weeks = byWeek.keys.where((w) => w.isBefore(currentWeek)).toList()
        ..sort((a, b) => b.compareTo(a));

      for (final week in weeks) {
        // A stored reflection (text OR silence) is done; never re-run.
        if (_store.read(week) != null) continue;
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
    final week = _weekOf(dateOnly(weekStart));
    final entries = [
      for (final e in _entries())
        if (_weekOfEntry(e) == week) e,
    ];
    await _reflectWeek(week, entries, force: true);
  }

  /// Removes a week's reflection.
  Future<void> deleteReflection(DateTime weekStart) async {
    await _store.delete(_weekOf(dateOnly(weekStart)));
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
    final text = inputs.isEmpty
        ? null
        : await _engine.reflect(entries: inputs, style: style, localeId: _language());

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

  /// The week's entries as the engine sees them: chronological, transcript only,
  /// with the weekday it was recorded on. Untranscribed entries have nothing to
  /// read and are dropped; the whole is capped to [_maxPromptChars].
  List<ReflectionEntryInput> _inputsFor(List<Entry> entries) {
    final ordered = [...entries]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final inputs = <ReflectionEntryInput>[];
    for (final e in ordered) {
      final text = e.transcript?.fullText.trim();
      if (text == null || text.isEmpty) continue;
      inputs.add(
        ReflectionEntryInput(weekday: e.createdAt.toLocal().weekday, text: text, title: e.title),
      );
    }
    return _capped(inputs);
  }

  /// Keeps the combined transcript text under [_maxPromptChars] so a heavy week
  /// cannot overflow the small on-device context window (a deterministic
  /// failure). Every day is kept but trimmed to an equal share, so the week's
  /// shape survives at reduced detail rather than a day being dropped whole.
  List<ReflectionEntryInput> _capped(List<ReflectionEntryInput> inputs) {
    if (inputs.isEmpty) return inputs;
    final total = inputs.fold<int>(0, (sum, i) => sum + i.text.length);
    if (total <= _maxPromptChars) return inputs;
    final share = _maxPromptChars ~/ inputs.length;
    return [
      for (final i in inputs)
        if (i.text.length <= share)
          i
        else
          ReflectionEntryInput(weekday: i.weekday, text: i.text.substring(0, share), title: i.title),
    ];
  }

  void _emitChanged() {
    if (!_changed.isClosed) _changed.add(null);
  }

  Future<void> dispose() => _changed.close();
}
