import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:opentranscribe/core/models/entry.dart';
import 'package:transcriber/transcriber.dart';

/// Where a bulk run stands. [idle] before the first run; a terminal phase
/// ([done], [cancelled]) keeps its counts until the next run resets them, so
/// a surface opened after the fact still reads what happened.
enum RetranscribePhase { idle, running, done, cancelled }

/// Why the queue is holding between entries, so the surface can say which
/// wait this is. [capture] outranks [thermal] when both apply.
enum RetranscribeHold { none, capture, thermal }

/// One snapshot of the bulk runner's progress.
@immutable
final class RetranscribeProgress {
  const RetranscribeProgress({
    this.phase = RetranscribePhase.idle,
    this.total = 0,
    this.landed = 0,
    this.failed = 0,
    this.currentEntryId,
    this.hold = RetranscribeHold.none,
  });

  final RetranscribePhase phase;

  /// The queue's size. Snapshotted at start, and SHRUNK when a queued entry
  /// stops qualifying mid-run (deleted, discarded, or re-transcribed by
  /// another path): such an entry is not a failure, it is no longer work.
  final int total;

  /// Entries whose re-transcription landed this run.
  final int landed;

  /// Entries whose re-transcription threw this run. A failed entry keeps its
  /// old state, still queued for the next run.
  final int failed;

  /// The entry being re-transcribed right now; null between entries and
  /// outside a run.
  final String? currentEntryId;

  /// The reason the queue is holding between entries (none while it
  /// transcribes); [waiting] is the surface's yes/no view of it.
  final RetranscribeHold hold;

  bool get waiting => hold != RetranscribeHold.none;

  /// Entries settled so far, landed and failed together: the "34" of
  /// "34 of 210".
  int get done => landed + failed;

  RetranscribeProgress copyWith({
    RetranscribePhase? phase,
    int? total,
    int? landed,
    int? failed,
    String? currentEntryId,
    RetranscribeHold? hold,
    bool clearCurrent = false,
  }) => RetranscribeProgress(
    phase: phase ?? this.phase,
    total: total ?? this.total,
    landed: landed ?? this.landed,
    failed: failed ?? this.failed,
    currentEntryId: clearCurrent ? null : (currentEntryId ?? this.currentEntryId),
    hold: hold ?? this.hold,
  );

  @override
  bool operator ==(Object other) =>
      other is RetranscribeProgress &&
      other.phase == phase &&
      other.total == total &&
      other.landed == landed &&
      other.failed == failed &&
      other.currentEntryId == currentEntryId &&
      other.hold == hold;

  @override
  int get hashCode => Object.hash(phase, total, landed, failed, currentEntryId, hold);
}

/// The bulk re-transcription queue: every kept recording the current engine
/// has not heard yet, run oldest first, one at a time, through the service's
/// atomic per-entry re-transcribe. Owned by TranscriptionService (constructed
/// there over closures onto its privates) so the entry lifecycle keeps one
/// owner; nothing here touches an engine, a store, or a file directly.
///
/// The contract a surface may rely on: [start] is single-flight and never
/// throws; a kill or [cancel] mid-run loses nothing (each entry lands
/// atomically, and what did not run is re-queued for free next time, because
/// the queue is derived from the transcripts' engine stamps rather than any
/// saved cursor); [cancel] takes effect between entries, and hard-cancels the
/// in-flight batch only when doing so cannot touch a user's own recording.
class RetranscribeRunner {
  RetranscribeRunner({
    required this._entries,
    required this._read,
    required this._retranscribe,
    required this._engineId,
    required this._hold,
    required this._hardCancelAllowed,
    required this._cancelInFlight,
    required this._notifyEntriesChanged,
  });

  final List<Entry> Function() _entries;
  final Entry? Function(String id) _read;
  final Future<void> Function(Entry entry) _retranscribe;
  final String Function() _engineId;

  /// Why the queue must hold between entries right now, or none: a live take
  /// or a finalize must never queue behind bulk work, and thermal pressure
  /// pauses the queue until the device cools.
  final RetranscribeHold Function() _hold;

  /// Whether cancelling the engine's in-flight batches can touch only bulk
  /// work: no capture, finalize, or user-initiated re-transcription may have
  /// a batch in flight, because the hard cancel kills every batch and must
  /// never be what fails the user's own action. Deliberately its own closure,
  /// not derived from [_hold]: thermal pressure holds the queue but forbids
  /// nothing, since only bulk work can be in flight then.
  final bool Function() _hardCancelAllowed;

  final Future<void> Function() _cancelInFlight;
  final void Function() _notifyEntriesChanged;

  /// One deference beat. Injectable so tests never sleep a wall-clock second.
  @visibleForTesting
  Future<void> Function() wait = _defaultWait;

  static Future<void> _defaultWait() => Future<void>.delayed(const Duration(seconds: 1));

  final StreamController<RetranscribeProgress> _progress =
      StreamController<RetranscribeProgress>.broadcast();

  RetranscribeProgress _state = const RetranscribeProgress();
  Future<RetranscribeProgress>? _running;
  bool _cancelRequested = false;

  /// The latest snapshot; [stream] carries every change.
  RetranscribeProgress get state => _state;

  Stream<RetranscribeProgress> get stream => _progress.stream;

  bool get isRunning => _running != null;

  /// Whether a run would (re-)transcribe [entry]: it keeps audio, and the
  /// current engine has not produced its transcript. The one spelling of the
  /// skip rule, shared with the surfaces that preview a run, so the preview
  /// and the queue can never disagree.
  bool runnable(Entry entry) =>
      entry.hasAudio && (entry.transcript == null || entry.transcript!.engineId != _engineId());

  /// Runs the queue to a terminal state and returns it. Single-flight: a call
  /// while running returns the run already in flight. Never throws; per-entry
  /// failures are counted and the queue moves on.
  Future<RetranscribeProgress> start() {
    final pending = _running;
    if (pending != null) return pending;
    _cancelRequested = false;
    final future = _run();
    _running = future;
    future.whenComplete(() {
      if (identical(_running, future)) _running = null;
    });
    return future;
  }

  /// Asks the current run to stop. The queue ends between entries; the
  /// in-flight batch is hard-cancelled only when [_hardCancelAllowed] says no
  /// user work can be the casualty, and otherwise runs to its own end first.
  /// A no-op when idle.
  void cancel() {
    if (_running == null) return;
    _cancelRequested = true;
    if (_hardCancelAllowed()) {
      unawaited(_cancelInFlight().catchError((_) {}));
    }
  }

  Future<RetranscribeProgress> _run() async {
    final queue = _entries().where(runnable).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    _emit(RetranscribeProgress(phase: RetranscribePhase.running, total: queue.length));
    for (final queued in queue) {
      var hold = _hold();
      while (!_cancelRequested && hold != RetranscribeHold.none) {
        if (_state.hold != hold) _emit(_state.copyWith(hold: hold));
        await wait();
        hold = _hold();
      }
      if (_state.waiting) _emit(_state.copyWith(hold: RetranscribeHold.none));
      if (_cancelRequested) break;
      // Re-read and re-check: the queue is a snapshot, and this entry may
      // have been deleted, discarded, or re-transcribed since it was taken.
      final stored = _read(queued.id);
      if (stored == null || !runnable(stored)) {
        _emit(_state.copyWith(total: _state.total - 1));
        continue;
      }
      _emit(_state.copyWith(currentEntryId: stored.id));
      try {
        await _retranscribe(stored);
        _emit(_state.copyWith(landed: _state.landed + 1, clearCurrent: true));
        _notifyEntriesChanged();
      } catch (error) {
        // Under a cancel the throw is likely the hard cancel's own doing;
        // the entry was not tried and found wanting, so it is not a failure.
        // A delete landing DURING the batch is not one either, and neither is
        // a recording that is gone: no later run can transcribe it, so
        // counting it as a failure would queue it again forever.
        if (_cancelRequested) {
          _emit(_state.copyWith(clearCurrent: true));
        } else if (_read(queued.id) == null || error is RecordingMissing) {
          _emit(_state.copyWith(total: _state.total - 1, clearCurrent: true));
        } else {
          _emit(_state.copyWith(failed: _state.failed + 1, clearCurrent: true));
        }
      }
    }
    _emit(
      _state.copyWith(
        phase: _cancelRequested ? RetranscribePhase.cancelled : RetranscribePhase.done,
        hold: RetranscribeHold.none,
        clearCurrent: true,
      ),
    );
    return _state;
  }

  void _emit(RetranscribeProgress next) {
    _state = next;
    if (!_progress.isClosed) _progress.add(next);
  }

  /// Ends any run (as a cancel) and closes the stream.
  Future<void> dispose() async {
    _cancelRequested = true;
    await _progress.close();
  }
}
