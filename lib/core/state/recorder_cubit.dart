// ignore_for_file: prefer_initializing_formals
// The field is private (a cubit owns its collaborators) and the constructor must
// call super(state), so an initializing formal does not apply.

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/models/entry.dart';
import 'package:opentranscribe/core/services/transcription_service.dart';
import 'package:opentranscribe/core/transcribe/transcript_event.dart';

enum RecorderStatus { idle, recording, saving }

class RecorderState {
  const RecorderState({
    this.status = RecorderStatus.idle,
    this.elapsed = Duration.zero,
    this.liveText = '',
    this.error,
  });

  final RecorderStatus status;
  final Duration elapsed;
  final String liveText;
  final String? error;

  bool get isRecording => status == RecorderStatus.recording;
  bool get isBusy => status != RecorderStatus.idle;

  RecorderState copyWith({
    RecorderStatus? status,
    Duration? elapsed,
    String? liveText,
    String? error,
    bool clearError = false,
  }) => RecorderState(
    status: status ?? this.status,
    elapsed: elapsed ?? this.elapsed,
    liveText: liveText ?? this.liveText,
    error: clearError ? null : (error ?? this.error),
  );
}

/// Drives a single recording session over the [TranscriptionService]: live text,
/// an elapsed timer, and the saved entry on stop. Errors (e.g. denied mic
/// permission) surface on the state rather than throwing.
class RecorderCubit extends Cubit<RecorderState> {
  RecorderCubit({required TranscriptionService service})
    : _service = service,
      super(const RecorderState());

  final TranscriptionService _service;
  StreamSubscription<TranscriptEvent>? _liveSub;
  Timer? _timer;

  /// The in-flight startRecording call. stop() awaits it before stopping, so a
  /// stop tapped during the start round-trip cannot see "not recording", error
  /// out, and strand a hot microphone that the UI can no longer stop.
  Future<void>? _startInFlight;

  Future<void> start() async {
    if (state.isBusy) return;
    emit(const RecorderState(status: RecorderStatus.recording));
    _liveSub = _service.liveEvents.listen(
      (event) => emit(state.copyWith(liveText: event.text)),
      onError: (_) {},
    );
    final starting = _service.startRecording();
    _startInFlight = starting;
    try {
      await starting;
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        emit(state.copyWith(elapsed: state.elapsed + const Duration(seconds: 1)));
      });
    } catch (e) {
      await _teardown();
      emit(RecorderState(error: _message(e)));
    } finally {
      if (identical(_startInFlight, starting)) _startInFlight = null;
    }
  }

  Future<Entry?> stop() async {
    if (!state.isRecording) return null;
    // Let an in-flight start settle first; its failure path already emitted.
    final starting = _startInFlight;
    if (starting != null) {
      try {
        await starting;
      } catch (_) {
        return null;
      }
    }
    if (!_service.isRecording) return null;
    _timer?.cancel();
    emit(state.copyWith(status: RecorderStatus.saving));
    try {
      final entry = await _service.stopRecording();
      await _teardown();
      emit(const RecorderState());
      return entry;
    } catch (e) {
      await _teardown();
      emit(RecorderState(error: _message(e)));
      return null;
    }
  }

  void clearError() => emit(state.copyWith(clearError: true));

  Future<void> _teardown() async {
    _timer?.cancel();
    _timer = null;
    await _liveSub?.cancel();
    _liveSub = null;
  }

  String _message(Object error) => error.toString();

  @override
  Future<void> close() async {
    await _teardown();
    return super.close();
  }
}
