// ignore_for_file: prefer_initializing_formals
// The fields are private (a cubit owns its collaborators) and the constructor
// must call super(state), so initializing formals do not apply.

import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:opentranscribe/core/notify/notification_scheduler.dart';
import 'package:opentranscribe/core/notify/reflection_notifier.dart';
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
    this.reminders = NotificationPermission.notDetermined,
    this.requestingMic = false,
    this.requestingSpeech = false,
    this.requestingReminders = false,
  });

  final PermissionStatus mic;
  final SpeechPermission speech;

  /// Notification permission for the reflection reminders, as answered here.
  final NotificationPermission reminders;

  /// A prompt is in flight, so the row shows a spinner and ignores a second tap.
  final bool requestingMic;
  final bool requestingSpeech;
  final bool requestingReminders;

  bool get micGranted => mic == PermissionStatus.granted;
  bool get speechGranted => speech == SpeechPermission.granted;
  bool get remindersGranted => reminders == NotificationPermission.authorized;
  bool get requesting => requestingMic || requestingSpeech || requestingReminders;

  OnboardingState copyWith({
    PermissionStatus? mic,
    SpeechPermission? speech,
    NotificationPermission? reminders,
    bool? requestingMic,
    bool? requestingSpeech,
    bool? requestingReminders,
  }) => OnboardingState(
    mic: mic ?? this.mic,
    speech: speech ?? this.speech,
    reminders: reminders ?? this.reminders,
    requestingMic: requestingMic ?? this.requestingMic,
    requestingSpeech: requestingSpeech ?? this.requestingSpeech,
    requestingReminders: requestingReminders ?? this.requestingReminders,
  );
}

/// Drives the onboarding set-up step: it triggers the native mic, speech and
/// notification prompts and reports the answers. It never blocks the flow - a
/// denied permission is a state to show, not a wall (recording re-prompts on
/// first use, reminders wait on the notifications screen).
class OnboardingCubit extends Cubit<OnboardingState> {
  OnboardingCubit({
    required TranscriptionService service,
    required NotificationScheduler scheduler,
    required ReflectionNotifier notifier,
  }) : _service = service,
       _scheduler = scheduler,
       _notifier = notifier,
       super(const OnboardingState());

  final TranscriptionService _service;
  final NotificationScheduler _scheduler;
  final ReflectionNotifier _notifier;

  /// Fires the system prompts the set-up page primes for, in order, skipping
  /// any already answered. The page's button must run this before advancing:
  /// App Store 5.1.1(iv) requires a priming message to always lead to the
  /// actual permission request. [reminders] is false where the phone cannot
  /// reflect: no reminder can ever fire there, so nothing is asked.
  Future<void> requestPending({required bool reminders}) async {
    // A second pass while a prompt is up would start the next prompt over it.
    if (state.requesting) return;
    if (state.mic == PermissionStatus.undetermined) await requestMic();
    if (state.speech == SpeechPermission.undetermined) await requestSpeech();
    if (reminders && state.reminders == NotificationPermission.notDetermined) {
      await requestReminders();
    }
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

  /// Asks for notification permission and, when it is granted, turns the
  /// reminders on right here, so a yes on this page needs no second visit to
  /// the notifications screen. A no stores nothing: that screen still offers
  /// them later.
  Future<void> requestReminders() async {
    if (state.requestingReminders) return;
    emit(state.copyWith(requestingReminders: true));
    try {
      final granted = await _scheduler.requestPermission();
      if (granted) await _notifier.enable();
      final status = await _scheduler.permissionStatus();
      if (!isClosed) emit(state.copyWith(reminders: status));
    } catch (_) {
      // Same as the mic: no answer, retryable.
    } finally {
      if (!isClosed) emit(state.copyWith(requestingReminders: false));
    }
  }
}
