// ignore_for_file: prefer_initializing_formals
// The field is private (a cubit owns its collaborators) and the constructor must
// call super(state), so an initializing formal does not apply.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/services/transcript_stitch.dart';
import 'package:opentranscribe/core/services/transcription_service.dart';
import 'package:transcriber/transcriber.dart';

enum RecorderStatus { idle, recording, paused, saving, restarting }

/// Typed failure kinds, so the UI renders localized copy instead of raw
/// exception text. Permission is its own kind because it has its own surface
/// (a persistent in-screen state, not a dialog).
enum RecorderError { permissionDenied, entryBusy, generic }

class RecorderState {
  const RecorderState({
    this.status = RecorderStatus.idle,
    this.elapsed = Duration.zero,
    this.liveText = '',
    this.liveUnavailable = false,
    this.heardSound = false,
    this.localeId = '',
    this.takeId = 0,
    this.live = false,
    this.error,
    this.interrupted = false,
    this.continuing,
  });

  final RecorderStatus status;
  final Duration elapsed;
  final String liveText;

  /// A non-terminal live-transcription failure: the settling batch on stop is
  /// unaffected, so recording continues, but the live window has nothing to
  /// show and the screen says so calmly. Cleared the moment live text resumes.
  /// The raw native reason is debug-logged, never carried in state.
  final bool liveUnavailable;

  /// Whether the microphone has heard real sound this take (input level crossed
  /// [RecorderCubit._kHeardThreshold] at least once). This, NOT [liveText], is
  /// what tells an X-to-discard whether the take is worth keeping: the live
  /// stream can be blank while real speech was captured, and the batch pass on
  /// stop reads the audio the live engine could not. Latches true for the take.
  final bool heardSound;

  /// The language THIS session transcribes in: the app default at start,
  /// changeable mid-take via [RecorderCubit.setLanguage]. Session-only; the
  /// next take starts from the default again.
  final String localeId;

  /// Whether the MICROPHONE is open, which is later than [isRecording]: the
  /// status is emitted the moment the screen asks, while this waits for the
  /// platform to answer. Everything that confirms capture to the user hangs
  /// off this one, so nothing ever claims to be listening before it is.
  final bool live;

  /// Identifies the current take. Advances on every fresh start, so views
  /// holding their own buffer of a take (the waveform) can drop it when a
  /// restart discards the recording, while a pause keeps its bars.
  final int takeId;
  final RecorderError? error;

  /// The capture died under this take and the service auto-saved it. The
  /// screen shows a reassurance notice until the next run starts or the
  /// user dismisses it explicitly.
  final bool interrupted;

  /// The entry this take extends, null for a fresh take; a snapshot for the
  /// service, so read the live entry by id for anything shown. Every fresh
  /// state drops it.
  final Entry? continuing;

  bool get isRecording => status == RecorderStatus.recording;
  bool get isPaused => status == RecorderStatus.paused;
  bool get isBusy => status != RecorderStatus.idle;

  RecorderState copyWith({
    RecorderStatus? status,
    Duration? elapsed,
    String? liveText,
    bool? liveUnavailable,
    bool? heardSound,
    String? localeId,
    int? takeId,
    bool? live,
    RecorderError? error,
    bool clearError = false,
    bool? interrupted,
    Entry? continuing,
  }) => RecorderState(
    status: status ?? this.status,
    elapsed: elapsed ?? this.elapsed,
    liveText: liveText ?? this.liveText,
    liveUnavailable: liveUnavailable ?? this.liveUnavailable,
    heardSound: heardSound ?? this.heardSound,
    localeId: localeId ?? this.localeId,
    takeId: takeId ?? this.takeId,
    live: live ?? this.live,
    error: clearError ? null : (error ?? this.error),
    interrupted: interrupted ?? this.interrupted,
    continuing: continuing ?? this.continuing,
  );
}

/// Drives a single recording session over the [TranscriptionService]: live text,
/// an elapsed timer, pause and discard, and the saved entry on stop. Errors
/// (e.g. denied mic permission) surface on the state rather than throwing.
class RecorderCubit extends Cubit<RecorderState> {
  RecorderCubit({required TranscriptionService service, DateTime Function()? now})
    : _service = service,
      _now = now ?? DateTime.now,
      super(const RecorderState()) {
    _autoSub = _service.autoFinalized.listen(
      (_) => _onInterrupted(),
      onError: (Object error) {
        // The capture died either way: settle the clock and the live claim.
        _onInterrupted();
        // A failed interruption save is recoverable via retrySave; this cubit is
        // app-scoped (always alive), so it is the one owner that runs it, rather
        // than leaving the audio for the next-launch sweep.
        if (error is EntrySaveFailed) {
          final take = _takes;
          unawaited(_recoverSave(error.entry, take));
        }
      },
    );
  }

  final TranscriptionService _service;

  /// The wall clock, injectable so tests can move time deterministically.
  final DateTime Function() _now;

  StreamSubscription<TranscriptEvent>? _liveSub;

  /// Watches the input level so [RecorderState.heardSound] can latch when the
  /// mic hears real sound, independent of whether the live engine transcribed it.
  StreamSubscription<double>? _levelSub;

  /// Input level (0..1, native `(dBFS + 60) / 60`) above which the take counts as
  /// having heard real sound: digital silence sits near 0, quiet room tone near
  /// 0.2, and any spoken word peaks well above this. Set to clear the room floor
  /// without ever missing speech - discarding a real take is the failure to avoid.
  static const double _kHeardThreshold = 0.3;

  /// How long a continuation waits to learn whether its entry's language is
  /// ready before opening in the default; a hung probe must not hold the
  /// microphone closed.
  static const Duration _kLocaleProbeTimeout = Duration(seconds: 2);

  /// Recorded time banked by earlier runs of this take (before pauses and
  /// interruptions); the live remainder is measured from [_runStart].
  Duration _elapsedBase = Duration.zero;

  /// When the current run began, null while not running. Elapsed derives from
  /// the WALL CLOCK ([_elapsedBase] plus time since this mark), never from
  /// counting timer ticks: backgrounding throttles timers, and every missed
  /// tick used to vanish from the take's clock forever.
  DateTime? _runStart;

  /// Text committed by earlier language spans of THIS take, ending with the
  /// current span's `[fr]`-style marker. The live stream restarts on a
  /// language switch and its events only carry the new span, so the prefix is
  /// what keeps everything already spoken on screen.
  String _livePrefix = '';

  /// An interruption (a phone call) ends the capture natively and the service
  /// saves the entry itself. Without this the screen would keep counting into
  /// a microphone that is no longer open.
  late final StreamSubscription<Entry> _autoSub;
  Timer? _timer;

  /// True while a pause or resume round trip is in flight. Both check the
  /// status synchronously and then await the platform, so without this a second
  /// tap inside that window reaches the service and comes back as an error the
  /// user never earned.
  bool _switching = false;

  /// Takes started this session, the source of [RecorderState.takeId].
  int _takes = 0;

  /// The in-flight startRecording call. stop() awaits it before stopping, so a
  /// stop tapped during the start round-trip cannot see "not recording", error
  /// out, and strand a hot microphone that the UI can no longer stop.
  Future<void>? _startInFlight;

  /// The in-flight discard. A discard leaves the screen at once and tears the
  /// session down behind it, so a take asked for in that window waits for the
  /// old one to finish ending instead of failing on it.
  Future<void>? _discardInFlight;

  /// Input level while capturing, for the live waveform. A passthrough: the
  /// waveform buffers and interpolates on its own side.
  Stream<double> get inputLevel => _service.inputLevel;

  /// Clears a dead take's leftovers the MOMENT a recorder surface attaches,
  /// before [start] runs (start waits out the sheet's entrance). The cubit
  /// outlives its screens, so without this a fresh sheet opens wearing the
  /// LAST take's text and clock: its stop is still finalizing behind the
  /// popped sheet (status saving), or backgrounding killed the capture under
  /// a state still claiming to record. Quiet whenever a real session is in
  /// flight; the synchronous emit is the point, so nothing stale ever renders.
  void prepareTake() {
    if (!state.isBusy || _startInFlight != null || _service.isRecording) return;
    _resetRunState();
    // Advancing the take TAKES OWNERSHIP: a stop or cancel still finalizing
    // behind its popped sheet fails its ownership check from here on, so not
    // even its error can land on the fresh sheet this call just cleaned.
    emit(RecorderState(takeId: ++_takes));
  }

  /// Begins a take; with [continuing], one that extends that entry (see
  /// [TranscriptionService.startRecording]). A continuation opens in the
  /// entry's own language when the engine has it ready, else the default.
  Future<void> start({Entry? continuing}) async {
    // Nothing to wait for on the common path, so the busy check below still
    // runs synchronously and two rapid starts cannot both pass it.
    final ending = _discardInFlight;
    if (ending != null) await ending;
    if (state.isBusy) {
      // A take in flight owns the session and this is a duplicate ask - a
      // second tap, or a screen re-asking. But BUSY with no capture and no
      // start behind it is a leak from a screen that is already gone (a stop
      // that no-opped on a state it could not stop, an interruption left
      // hanging), and the take asking now would inherit its text, its clock and
      // its status without ever recording a thing. Heal it rather than refuse.
      if (_startInFlight != null || _service.isRecording) return;
    }
    // Reset synchronously (see _resetRunState): the claim emitted below must
    // follow the busy check with no async gap, so nothing from a still-finalizing
    // previous take leaks in.
    _resetRunState();
    emit(
      RecorderState(
        status: RecorderStatus.recording,
        takeId: ++_takes,
        // The session opens in the app default; the service snapshots the
        // same value, so the chip and the batch agree from the first frame.
        localeId: _service.localeId,
        continuing: continuing,
      ),
    );
    _liveSub = _service.liveEvents.listen(
      (event) {
        if (!isClosed) {
          emit(state.copyWith(liveText: _livePrefix + event.text, liveUnavailable: false));
        }
      },
      // A live failure never tears down the take: the batch pass on stop is the
      // source of truth and still runs. The screen tells the user calmly that
      // live text is unavailable; the raw reason is only debug-logged.
      onError: (Object e) {
        if (kDebugMode) debugPrint('recorder: live transcription failed: $e');
        if (!isClosed) emit(state.copyWith(liveUnavailable: true));
      },
    );
    _levelSub = _service.inputLevel.listen((level) {
      // Latch once: this is what an X-to-discard consults, so it must not depend
      // on the live transcript, which can be blank over real speech.
      if (!state.heardSound && level >= _kHeardThreshold && !isClosed) {
        emit(state.copyWith(heardSound: true));
      }
    });
    final starting = _startTake(continuing);
    _startInFlight = starting;
    try {
      await starting;
      _startTimer();
      // The platform answered: the microphone is open now, not when the screen
      // asked for it.
      emit(state.copyWith(live: true));
    } catch (e) {
      await _teardown();
      emit(RecorderState(error: _kind(e)));
    } finally {
      if (identical(_startInFlight, starting)) _startInFlight = null;
    }
  }

  Future<void> _startTake(Entry? continuing) async {
    final take = _takes;
    final tag = await _openingLocale(continuing);
    // A chip tapped during the probe wins: its own switch lands after start.
    final untouched = take == _takes && state.localeId == _service.localeId;
    final opening = untouched ? tag : null;
    if (opening != null && !isClosed) emit(state.copyWith(localeId: opening));
    await _service.startRecording(continuing: continuing, localeId: opening);
  }

  /// The entry's language when it differs from the default and is ready now;
  /// null keeps the default.
  Future<String?> _openingLocale(Entry? continuing) async {
    final tag = continuing?.effectiveLocaleId;
    if (tag == null || tag == _service.localeId) return null;
    try {
      final status = await _service.localeStatus(tag).timeout(_kLocaleProbeTimeout);
      return status.isReady ? tag : null;
    } catch (_) {
      return null;
    }
  }

  /// Suspends the session: timer and mic go quiet, the take stays open.
  Future<void> pause() async {
    if (!state.isRecording || _switching) return;
    _switching = true;
    try {
      // A pause tapped while the sheet is still rising races the start
      // round-trip; wait it out like stop() does instead of surfacing a bogus
      // "not recording" error for an innocent tap.
      final starting = _startInFlight;
      if (starting != null) {
        try {
          await starting;
        } catch (_) {
          return;
        }
      }
      if (!_service.isRecording) return;
      await _service.pauseRecording();
      // A stop can also land DURING this await: pauseRecording then returns
      // normally (its own entry guard already passed) but the service is no
      // longer recording, so this pause must not paint paused chrome over a
      // session the stop already ended.
      if (!_service.isRecording) return;
      _timer?.cancel();
      _timer = null;
      // Bank the run so the frozen clock is exact, not whatever the last
      // one-second tick happened to show.
      _elapsedBase = _currentElapsed();
      _runStart = null;
      emit(state.copyWith(status: RecorderStatus.paused, elapsed: _elapsedBase));
    } on StateError {
      // A stop won the race and flipped the service out of recording between the
      // check above and the pause await: the stop owns the outcome, so pausing a
      // take that is already ending is not a user-facing error.
    } catch (e) {
      // A stop that landed mid-pause can also make the recorder-level call fail
      // (the native session is already torn down): the stop owns that outcome
      // too, so only a genuine pause failure on a session still alive is
      // user-facing.
      if (_service.isRecording) emit(state.copyWith(error: _kind(e)));
    } finally {
      _switching = false;
    }
  }

  /// Continues a paused session; elapsed keeps its value, so pauses do not count.
  Future<void> resume() async {
    if (!state.isPaused || _switching) return;
    _switching = true;
    try {
      await _service.resumeRecording();
      _startTimer();
      emit(state.copyWith(status: RecorderStatus.recording));
    } catch (e) {
      // A route change discovered mid-resume tears the session down and
      // finalizes it as an interruption (see AudioCapture.swift's resume()):
      // that path owns the outcome, so this must not also paint an error over
      // its calm "we saved your recording" notice.
      if (_service.isRecording || _service.isPaused) emit(state.copyWith(error: _kind(e)));
    } finally {
      _switching = false;
    }
  }

  /// Discards the current take and begins a fresh one. A failed fresh start
  /// lands idle with the error surfaced, like any failed start.
  Future<void> restart() async {
    if (!state.isRecording && !state.isPaused) return;
    // Leaving recording synchronously first: the discard must not leave a
    // window where complete or a second control can act on the dying session.
    // Its own status, not saving: nothing is being saved, and the screen keeps
    // the recording chrome steady instead of flashing save affordances.
    emit(state.copyWith(status: RecorderStatus.restarting));
    // Publish the teardown like cancel() does, so a concurrent start()/cancel()
    // waits it out instead of racing _teardown(). Cleared before start() below,
    // so start()'s own _discardInFlight await sees null (no self-deadlock).
    final continuing = state.continuing;
    final ending = _cancelSession(forRestart: continuing != null);
    _discardInFlight = ending;
    try {
      await ending;
    } finally {
      if (identical(_discardInFlight, ending)) _discardInFlight = null;
    }
    // The take id carries through the reset: dropping it to zero here would
    // remount every view keyed on it twice for one restart.
    emit(RecorderState(takeId: state.takeId));
    await start(continuing: continuing);
  }

  /// Discards the current take: no entry, no kept audio.
  Future<void> cancel() async {
    if (!state.isBusy) return;
    // Same ownership rule as stop(): this runs on behind a popped sheet, and
    // the final reset belongs to this take only.
    final take = _takes;
    emit(state.copyWith(status: RecorderStatus.saving));
    final ending = _cancelSession();
    _discardInFlight = ending;
    try {
      await ending;
    } finally {
      if (identical(_discardInFlight, ending)) _discardInFlight = null;
    }
    if (take == _takes) emit(const RecorderState());
  }

  Future<Entry?> stop() async {
    if (!state.isRecording && !state.isPaused) return null;
    // Let an in-flight start settle first; its failure path already emitted.
    final starting = _startInFlight;
    if (starting != null) {
      try {
        await starting;
      } catch (_) {
        return null;
      }
    }
    // No "is it still recording" guard: an interruption may have finalized the
    // take already, and stopRecording() is built to hand that entry back. Short
    // circuiting here would leave the user tapping complete on a saved take and
    // getting nothing.
    _timer?.cancel();
    // This stop runs on behind a popped sheet (the batch pass takes seconds),
    // and a NEW take may start meanwhile. Once one has, the cubit is that
    // take's: this stop must still return its entry, but may no longer touch
    // the state, the timer, or the live subscription it no longer owns.
    // Clobbering them was how a finished take wiped a fresh recording.
    final take = _takes;
    emit(state.copyWith(status: RecorderStatus.saving));
    try {
      final entry = await _service.stopRecording();
      if (take == _takes) {
        await _teardown();
        emit(const RecorderState());
      }
      return entry;
    } catch (e) {
      if (take == _takes) {
        await _teardown();
        emit(RecorderState(error: _kind(e)));
      }
      return null;
    }
  }

  /// Re-languages the current take (see [TranscriptionService.setSessionLocale]).
  /// Nothing already on screen is thrown away: the prior text commits into the
  /// prefix with the NEW language's `[fr]`-style marker, and the restarted
  /// stream appends after it. No marker when nothing was said yet; there is
  /// nothing to separate.
  Future<void> setLanguage(String tag) async {
    if (!state.isBusy || state.localeId == tag) return;
    final prior = state.liveText.trim();
    _livePrefix = prior.isEmpty ? '' : '$prior ${languageMarker(tag)} ';
    emit(state.copyWith(localeId: tag, liveText: _livePrefix));
    try {
      // A switch tapped while the sheet is still rising races the start
      // round-trip; wait it out like pause() does. Without this the service
      // (not yet recording) drops the switch as a silent no-op, and the whole
      // take runs in the OLD language under a chip claiming the new one.
      final starting = _startInFlight;
      if (starting != null) {
        try {
          await starting;
        } catch (_) {
          return;
        }
      }
      await _service.setSessionLocale(tag);
    } catch (e) {
      emit(state.copyWith(error: _kind(e)));
    }
  }

  void clearError() => emit(state.copyWith(clearError: true));

  void clearInterrupted() => emit(state.copyWith(interrupted: false));

  Future<void> _cancelSession({bool forRestart = false}) async {
    final starting = _startInFlight;
    if (starting != null) {
      try {
        await starting;
      } catch (_) {
        // The failed start already tore down and emitted; nothing to cancel.
      }
    }
    try {
      await _service.cancelRecording(forRestart: forRestart);
    } catch (_) {
      // Cancel is a discard; a session that already ended is a success here.
    }
    await _teardown();
  }

  /// The capture ended under us. The take is already saved by the service, so
  /// the session stays open for complete to claim it; only the things that
  /// would now be lying stop: the clock, and the claim that the mic is live.
  void _onInterrupted() {
    // A stale interruption for a PAST take must not settle a fresh one: if the
    // service is recording again, a new take owns the cubit now. Only stop() and
    // cancel() carry a captured take id; this event has none, so the live service
    // state is the ownership check.
    if (_service.isRecording) return;
    if (!state.isRecording && !state.isPaused) return;
    _timer?.cancel();
    _timer = null;
    // Settle the clock at the moment capture died, so the frozen display
    // matches what was actually recorded.
    _elapsedBase = _currentElapsed();
    _runStart = null;
    // clearError: a stale error from a losing resume/pause must not share the
    // screen with the calm "we saved your recording" notice this emit paints.
    emit(state.copyWith(live: false, elapsed: _elapsedBase, interrupted: true, clearError: true));
  }

  /// The interruption's own save failed. Recover the audio's record (so it is not
  /// left for the next-launch sweep), and only surface an error if even that
  /// fails, on the same take that heard the failure.
  Future<void> _recoverSave(Entry entry, int take) async {
    try {
      await _service.recoverInterruptedSave(entry);
    } catch (e) {
      if (!isClosed && take == _takes) emit(state.copyWith(error: _kind(e)));
    }
  }

  /// Recorded time so far: the banked base plus the current run's wall-clock
  /// span. Reading the clock (rather than counting ticks) keeps it honest
  /// through background throttling and missed frames.
  Duration _currentElapsed() {
    final runStart = _runStart;
    if (runStart == null) return _elapsedBase;
    // Clamp to non-negative: a backward wall-clock adjustment (NTP, the user
    // changing the clock) mid-run would otherwise shrink the displayed elapsed.
    final delta = _now().difference(runStart);
    return _elapsedBase + (delta.isNegative ? Duration.zero : delta);
  }

  void _startTimer() {
    // Never leave one running: two resumes landing together would otherwise
    // strand a periodic timer that nothing can cancel, doubling the clock and
    // emitting after close.
    _timer?.cancel();
    _runStart = _now();
    // The tick is only a repaint cadence; the value always comes from the clock.
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      emit(state.copyWith(elapsed: _currentElapsed()));
    });
  }

  /// Clears any per-run state a previous take left in flight (timer, prefix,
  /// clock, live/level subscriptions), so nothing leaks into the next take.
  /// Synchronous on purpose: [start] must reset and emit its claim with no async
  /// gap, or two rapid starts (and a switch or pause racing the start round-trip)
  /// both slip through the busy check. Cancelling a broadcast subscription
  /// detaches it at the call, so the unawaited cancels cannot leak an event into
  /// the new state.
  void _resetRunState() {
    _timer?.cancel();
    _timer = null;
    _livePrefix = '';
    _elapsedBase = Duration.zero;
    _runStart = null;
    unawaited(_liveSub?.cancel());
    _liveSub = null;
    unawaited(_levelSub?.cancel());
    _levelSub = null;
  }

  Future<void> _teardown() async {
    _timer?.cancel();
    _timer = null;
    _livePrefix = '';
    _elapsedBase = Duration.zero;
    _runStart = null;
    await _liveSub?.cancel();
    _liveSub = null;
    await _levelSub?.cancel();
    _levelSub = null;
  }

  RecorderError _kind(Object error) {
    // The UI can only say "couldn't record"; the reason itself would otherwise
    // be swallowed here, and a capture failure is the hardest kind to guess at
    // after the fact.
    if (kDebugMode) debugPrint('recorder: $error');
    return switch (error) {
      PermissionDenied() => RecorderError.permissionDenied,
      ContinuationRefused() => RecorderError.entryBusy,
      _ => RecorderError.generic,
    };
  }

  @override
  Future<void> close() async {
    await _teardown();
    await _autoSub.cancel();
    return super.close();
  }
}
