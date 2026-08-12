import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/notify/notification_scheduler.dart';
import 'package:opentranscribe/core/services/entry_store.dart';
import 'package:opentranscribe/core/services/transcription_service.dart';
import 'package:opentranscribe/core/state/onboarding_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transcriber/testing.dart';
import 'package:transcriber/transcriber.dart';

import '../../support/fake_audio_recorder.dart';
import '../../support/fake_notification_scheduler.dart';

void main() {
  late LocalService storage;
  late EntryStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = LocalService();
    await storage.init(legacyKey: 'test-encryption-key-0123456789ab');
    store = EntryStore(storage);
  });

  OnboardingCubit build({
    PermissionStatus mic = PermissionStatus.granted,
    Availability availability = const Availability.available(),
    bool micThrows = false,
    bool speechThrows = false,
    FakeNotificationScheduler? scheduler,
  }) {
    final service = TranscriptionService(
      recorder: FakeAudioRecorder(permission: mic, throwOnEnsurePermission: micThrows),
      engine: FakeStreamingEngine(
        availability: availability,
        throwOnCheckAvailability: speechThrows,
      ),
      store: store,
    );
    return OnboardingCubit(service: service, scheduler: scheduler ?? FakeNotificationScheduler());
  }

  test('requestMic reflects a granted microphone permission', () async {
    final cubit = build();
    expect(cubit.state.micGranted, isFalse);
    await cubit.requestMic();
    expect(cubit.state.mic, PermissionStatus.granted);
    expect(cubit.state.micGranted, isTrue);
    expect(cubit.state.requestingMic, isFalse);
    await cubit.close();
  });

  test('requestMic reflects a denied microphone permission', () async {
    final cubit = build(mic: PermissionStatus.denied);
    await cubit.requestMic();
    expect(cubit.state.mic, PermissionStatus.denied);
    expect(cubit.state.micGranted, isFalse);
    await cubit.close();
  });

  test('requestSpeech maps a permission-denied availability to denied', () async {
    final cubit = build(availability: const Availability(AvailabilityStatus.permissionDenied));
    await cubit.requestSpeech();
    expect(cubit.state.speech, SpeechPermission.denied);
    expect(cubit.state.speechGranted, isFalse);
    await cubit.close();
  });

  test('a throwing mic request resets the spinner and keeps the tap retryable', () async {
    // A channel error is not an answer: the status must stay undetermined so
    // the Allow button comes back instead of a spinner stuck forever.
    final cubit = build(micThrows: true);
    await cubit.requestMic();
    expect(cubit.state.mic, PermissionStatus.undetermined);
    expect(cubit.state.requestingMic, isFalse);
    // The in-flight guard must not eat the retry.
    await cubit.requestMic();
    expect(cubit.state.requestingMic, isFalse);
    await cubit.close();
  });

  test('a throwing speech request resets the spinner and keeps the tap retryable', () async {
    final cubit = build(speechThrows: true);
    await cubit.requestSpeech();
    expect(cubit.state.speech, SpeechPermission.undetermined);
    expect(cubit.state.requestingSpeech, isFalse);
    await cubit.requestSpeech();
    expect(cubit.state.requestingSpeech, isFalse);
    await cubit.close();
  });

  test('requestSpeech treats available and model-unavailable alike as granted', () async {
    // Authorization is the only question here; a missing model is the model
    // step's problem, not a denied permission.
    for (final availability in const [
      Availability.available(),
      Availability(AvailabilityStatus.onDeviceUnavailable),
    ]) {
      final cubit = build(availability: availability);
      await cubit.requestSpeech();
      expect(cubit.state.speech, SpeechPermission.granted, reason: '$availability');
      await cubit.close();
    }
  });

  test('requestNotification reflects an authorized grant', () async {
    final cubit = build(scheduler: FakeNotificationScheduler());
    expect(cubit.state.notificationGranted, isFalse);
    await cubit.requestNotification();
    expect(cubit.state.notification, NotificationPermission.authorized);
    expect(cubit.state.notificationGranted, isTrue);
    expect(cubit.state.requestingNotification, isFalse);
    await cubit.close();
  });

  test('requestNotification reflects a denied grant', () async {
    final cubit = build(scheduler: FakeNotificationScheduler(grant: false));
    await cubit.requestNotification();
    expect(cubit.state.notification, NotificationPermission.denied);
    expect(cubit.state.notificationGranted, isFalse);
    await cubit.close();
  });

  test('a throwing notification probe resets the spinner and keeps the tap retryable', () async {
    final scheduler = FakeNotificationScheduler()
      ..onPermissionProbe = () async => throw StateError('no channel');
    final cubit = build(scheduler: scheduler);
    await cubit.requestNotification();
    expect(cubit.state.notification, NotificationPermission.notDetermined);
    expect(cubit.state.requestingNotification, isFalse);
    await cubit.requestNotification();
    expect(cubit.state.requestingNotification, isFalse);
    await cubit.close();
  });
}
