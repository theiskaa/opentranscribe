// ignore_for_file: prefer_initializing_formals
// The field is private (a cubit owns its collaborators) and the constructor must
// call super(state), so an initializing formal does not apply.

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/audio/recording.dart';
import 'package:opentranscribe/core/notify/notification_scheduler.dart';
import 'package:opentranscribe/core/services/transcription_service.dart';
import 'package:opentranscribe/core/transcribe/transcription_engine.dart';

/// Speech-recognition authorization as onboarding cares about it: only whether
/// the user has been asked and answered. The model's own readiness is the model
/// step's concern, not this - an authorized engine with no model still counts
/// as granted here.
enum SpeechPermission { undetermined, granted, denied }

class OnboardingState {
  const OnboardingState({
    this.mic = PermissionStatus.undetermined,
    this.speech = SpeechPermission.undetermined,
    this.notification = NotificationPermission.notDetermined,
    this.requestingMic = false,
    this.requestingSpeech = false,
    this.requestingNotification = false,
  });

  final PermissionStatus mic;
  final SpeechPermission speech;

  /// The weekly-reflection nudge permission, offered only on eligible hardware.
  /// Optional: unlike mic and speech, skipping it costs the flow nothing, and
  /// the nudge toggle later asks contextually for anyone who does.
  final NotificationPermission notification;

  /// A prompt is in flight, so the row shows a spinner and ignores a second tap.
  final bool requestingMic;
  final bool requestingSpeech;
  final bool requestingNotification;

  bool get micGranted => mic == PermissionStatus.granted;
  bool get speechGranted => speech == SpeechPermission.granted;
  bool get notificationGranted => notification == NotificationPermission.authorized;

  OnboardingState copyWith({
    PermissionStatus? mic,
    SpeechPermission? speech,
    NotificationPermission? notification,
    bool? requestingMic,
    bool? requestingSpeech,
    bool? requestingNotification,
  }) => OnboardingState(
    mic: mic ?? this.mic,
    speech: speech ?? this.speech,
    notification: notification ?? this.notification,
    requestingMic: requestingMic ?? this.requestingMic,
    requestingSpeech: requestingSpeech ?? this.requestingSpeech,
    requestingNotification: requestingNotification ?? this.requestingNotification,
  );
}

/// Drives the onboarding permission step: it triggers the native mic and speech
/// prompts and reports the answers. It never blocks the flow - a denied
/// permission is a state to show, not a wall (recording re-prompts on first use).
class OnboardingCubit extends Cubit<OnboardingState> {
  OnboardingCubit({required TranscriptionService service, required NotificationScheduler scheduler})
    : _service = service,
      _scheduler = scheduler,
      super(const OnboardingState());

  final TranscriptionService _service;
  final NotificationScheduler _scheduler;

  Future<void> requestMic() async {
    if (state.requestingMic) return;
    emit(state.copyWith(requestingMic: true));
    try {
      final status = await _service.ensureMicPermission();
      if (!isClosed) emit(state.copyWith(mic: status));
    } catch (_) {
      // A channel error is not an answer; leaving the status as-is brings the
      // Allow button back so the tap is retryable.
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
      // Same as the mic: no answer, keep the button.
    } finally {
      if (!isClosed) emit(state.copyWith(requestingSpeech: false));
    }
  }

  /// Fires the OS notification prompt once, then reflects the standing answer.
  /// Optional and non-blocking: a denial only means the weekly nudge cannot fire
  /// until it is restored in Settings, which the row surfaces.
  Future<void> requestNotification() async {
    if (state.requestingNotification) return;
    emit(state.copyWith(requestingNotification: true));
    try {
      // requestPermission prompts only when undetermined; permissionStatus then
      // reports the real grant (authorized covers provisional and ephemeral).
      await _scheduler.requestPermission();
      final status = await _scheduler.permissionStatus();
      if (!isClosed) emit(state.copyWith(notification: status));
    } catch (_) {
      // No answer; leave the status so the Allow button returns for a retry.
    } finally {
      if (!isClosed) emit(state.copyWith(requestingNotification: false));
    }
  }
}
