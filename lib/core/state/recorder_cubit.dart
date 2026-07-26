// ignore_for_file: prefer_initializing_formals
// The field is private (a cubit owns its collaborators) and the constructor must
// call super(state), so an initializing formal does not apply.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/services/transcription_service.dart';
import 'package:opentranscribe/core/transcribe/transcript_event.dart';
import 'package:opentranscribe/core/transcribe/transcription_exception.dart';

enum RecorderStatus { idle, recording, paused, saving }

/// Typed failure kinds, so the UI renders localized copy instead of raw
/// exception text. Permission is its own kind because it has its own surface
/// (a persistent in-screen state, not a dialog).
enum RecorderError { permissionDenied, generic }

class RecorderState {
  const RecorderState({
    this.status = RecorderStatus.idle,
    this.elapsed = Duration.zero,
    this.liveText = '',
    this.localeId = '',
    this.takeId = 0,
    this.live = false,
    this.error,
  });

  final RecorderStatus status;
  final Duration elapsed;
  final String liveText;

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

  bool get isRecording => status == RecorderStatus.recording;
  bool get isPaused => status == RecorderStatus.paused;
  bool get isBusy => status != RecorderStatus.idle;

  RecorderState copyWith({
    RecorderStatus? status,
    Duration? elapsed,
    String? liveText,
    String? localeId,
    int? takeId,
    bool? live,
    RecorderError? error,
    bool clearError = false,
  }) => RecorderState(
    status: status ?? this.status,
    elapsed: elapsed ?? this.elapsed,
    liveText: liveText ?? this.liveText,
    localeId: localeId ?? this.localeId,
    takeId: takeId ?? this.takeId,
    live: live ?? this.live,
    error: clearError ? null : (error ?? this.error),
  );
}

/// Drives a single recording session over the [TranscriptionService]: live text,
/// an elapsed timer, pause and discard, and the saved entry on stop. Errors
/// (e.g. denied mic permission) surface on the state rather than throwing.
class RecorderCubit extends Cubit<RecorderState> {
  RecorderCubit({required TranscriptionService service})
    : _service = service,
      super(const RecorderState()) {
    _autoSub = _service.autoFinalized.listen(
      (_) => _onInterrupted(),
      onError: (Object _) => _onInterrupted(),
    );
  }

  final TranscriptionService _service;
  StreamSubscription<TranscriptEvent>? _liveSub;

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

  Future<void> start() async {
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
      await _teardown();
    }
    emit(
      RecorderState(
        status: RecorderStatus.recording,
        takeId: ++_takes,
        // The session opens in the app default; the service snapshots the
        // same value, so the chip and the batch agree from the first frame.
        localeId: _service.localeId,
      ),
    );
    _livePrefix = '';
    _liveSub = _service.liveEvents.listen(
      (event) => emit(state.copyWith(liveText: _livePrefix + event.text)),
      onError: (_) {},
    );
    final starting = _service.startRecording();
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
      _timer?.cancel();
      _timer = null;
      emit(state.copyWith(status: RecorderStatus.paused));
    } catch (e) {
      emit(state.copyWith(error: _kind(e)));
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
      emit(state.copyWith(error: _kind(e)));
    } finally {
      _switching = false;
    }
  }

  /// Discards the current take and begins a fresh one. A failed fresh start
  /// lands idle with the error surfaced, like any failed start.
  Future<void> restart() async {
    if (!state.isRecording && !state.isPaused) return;
    // Saving synchronously first: the discard must not leave a window where
    // complete or a second control can act on the dying session.
    emit(state.copyWith(status: RecorderStatus.saving));
    await _cancelSession();
    // The take id carries through the reset: dropping it to zero here would
    // remount every view keyed on it twice for one restart.
    emit(RecorderState(takeId: state.takeId));
    await start();
  }

  /// Discards the current take: no entry, no kept audio.
  Future<void> cancel() async {
    if (!state.isBusy) return;
    emit(state.copyWith(status: RecorderStatus.saving));
    final ending = _cancelSession();
    _discardInFlight = ending;
    try {
      await ending;
    } finally {
      if (identical(_discardInFlight, ending)) _discardInFlight = null;
    }
    emit(const RecorderState());
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
    emit(state.copyWith(status: RecorderStatus.saving));
    try {
      final entry = await _service.stopRecording();
      await _teardown();
      emit(const RecorderState());
      return entry;
    } catch (e) {
      await _teardown();
      emit(RecorderState(error: _kind(e)));
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
    _livePrefix = prior.isEmpty ? '' : '$prior [${tag.split('-').first}] ';
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

  Future<void> _cancelSession() async {
    final starting = _startInFlight;
    if (starting != null) {
      try {
        await starting;
      } catch (_) {
        // The failed start already tore down and emitted; nothing to cancel.
      }
    }
    try {
      await _service.cancelRecording();
    } catch (_) {
      // Cancel is a discard; a session that already ended is a success here.
    }
    await _teardown();
  }

  /// The capture ended under us. The take is already saved by the service, so
  /// the session stays open for complete to claim it; only the things that
  /// would now be lying stop: the clock, and the claim that the mic is live.
  void _onInterrupted() {
    if (!state.isRecording && !state.isPaused) return;
    _timer?.cancel();
    _timer = null;
    emit(state.copyWith(live: false));
  }

  void _startTimer() {
    // Never leave one running: two resumes landing together would otherwise
    // strand a periodic timer that nothing can cancel, doubling the clock and
    // emitting after close.
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      emit(state.copyWith(elapsed: state.elapsed + const Duration(seconds: 1)));
    });
  }

  Future<void> _teardown() async {
    _timer?.cancel();
    _timer = null;
    _livePrefix = '';
    await _liveSub?.cancel();
    _liveSub = null;
  }

  RecorderError _kind(Object error) {
    // The UI can only say "couldn't record"; the reason itself would otherwise
    // be swallowed here, and a capture failure is the hardest kind to guess at
    // after the fact.
    if (kDebugMode) debugPrint('recorder: $error');
    return error is PermissionDenied ? RecorderError.permissionDenied : RecorderError.generic;
  }

  @override
  Future<void> close() async {
    await _teardown();
    await _autoSub.cancel();
    return super.close();
  }
}
