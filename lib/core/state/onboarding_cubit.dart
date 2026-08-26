// ignore_for_file: prefer_initializing_formals
// The field is private (a cubit owns its collaborators) and the constructor must
// call super(state), so an initializing formal does not apply.

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/services/transcription_service.dart';
import 'package:transcriber/transcriber.dart';

/// Speech-recognition authorization as onboarding cares about it: only whether
/// the user has been asked and answered. The model's own readiness is the model
/// step's concern, not this - an authorized engine with no model still counts
/// as granted here.
enum SpeechPermission { undetermined, granted, denied }

class OnboardingState {
  const OnboardingState({
    this.mic = PermissionStatus.undetermined,
    this.speech = SpeechPermission.undetermined,
    this.requestingMic = false,
    this.requestingSpeech = false,
  });

  final PermissionStatus mic;
  final SpeechPermission speech;

  /// A prompt is in flight, so the row shows a spinner and ignores a second tap.
  final bool requestingMic;
  final bool requestingSpeech;

  bool get micGranted => mic == PermissionStatus.granted;
  bool get speechGranted => speech == SpeechPermission.granted;

  OnboardingState copyWith({
    PermissionStatus? mic,
    SpeechPermission? speech,
    bool? requestingMic,
    bool? requestingSpeech,
  }) => OnboardingState(
    mic: mic ?? this.mic,
    speech: speech ?? this.speech,
    requestingMic: requestingMic ?? this.requestingMic,
    requestingSpeech: requestingSpeech ?? this.requestingSpeech,
  );
}

/// Drives the onboarding permission step: it triggers the native mic and speech
/// prompts and reports the answers. It never blocks the flow - a denied
/// permission is a state to show, not a wall (recording re-prompts on first use).
class OnboardingCubit extends Cubit<OnboardingState> {
  OnboardingCubit({required TranscriptionService service})
    : _service = service,
      super(const OnboardingState());

  final TranscriptionService _service;

  /// Fires the system prompts the permissions page primes for, in order,
  /// skipping any already answered. The page's Next button must run this before
  /// advancing: App Store 5.1.1(iv) requires a priming message to always lead
  /// to the actual permission request.
  Future<void> requestPending() async {
    if (state.mic == PermissionStatus.undetermined) await requestMic();
    if (state.speech == SpeechPermission.undetermined) await requestSpeech();
  }

  Future<void> requestMic() async {
    if (state.requestingMic) return;
    emit(state.copyWith(requestingMic: true));
    try {
      final status = await _service.ensureMicPermission();
      if (!isClosed) emit(state.copyWith(mic: status));
    } catch (_) {
      // A channel error is not an answer; leaving the status undetermined lets
      // the next Next tap retry the prompt.
    } finally {
      if (!isClosed) emit(state.copyWith(requestingMic: false));
    }
  }

  Future<void> requestSpeech() async {
    if (state.requestingSpeech) return;
    emit(state.copyWith(requestingSpeech: true));
    try {
      // Only permission-denied is a "no"; an authorized engine that simply lacks
      // a model still reads as granted here, since the model step handles the
      // model.
      final availability = await _service.checkAvailability();
      final speech = availability.status == AvailabilityStatus.permissionDenied
          ? SpeechPermission.denied
          : SpeechPermission.granted;
      if (!isClosed) emit(state.copyWith(speech: speech));
    } catch (_) {
      // Same as the mic: no answer, retryable.
    } finally {
      if (!isClosed) emit(state.copyWith(requestingSpeech: false));
    }
  }
}
