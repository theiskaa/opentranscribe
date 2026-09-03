import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/notify/notification_scheduler.dart';
import 'package:opentranscribe/core/notify/reflection_notifier.dart';
import 'package:opentranscribe/core/services/notification_settings.dart';
import 'package:opentranscribe/core/services/reflection_settings.dart';
import 'package:opentranscribe/core/services/entry_store.dart';
import 'package:opentranscribe/core/services/transcription_service.dart';
import 'package:opentranscribe/core/state/onboarding_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transcriber/testing.dart';
import 'package:reflections/reflections.dart';
import 'package:transcriber/transcriber.dart';

import '../../support/fake_audio_recorder.dart';
import '../../support/fake_notification_scheduler.dart';

void main() {
  late LocalService storage;
  late EntryStore store;
  late FakeAudioRecorder recorder;
  late FakeStreamingEngine engine;
  late FakeNotificationScheduler scheduler;
  late NotificationSettings notify;

  setUpAll(() async {
    await initializeDateFormatting();
  });

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
    bool grant = true,
  }) {
    scheduler = FakeNotificationScheduler(
      permission: NotificationPermission.notDetermined,
      grant: grant,
    );
    notify = NotificationSettings(storage: storage);
    final notifier = ReflectionNotifier(
      scheduler: scheduler,
      notifySettings: notify,
      reflectionSettings: ReflectionSettings(storage: storage),
      availability: () async => const ReflectionAvailability.available(),
      language: () => 'en',
    );
    recorder = FakeAudioRecorder(permission: mic, throwOnEnsurePermission: micThrows);
    engine = FakeStreamingEngine(
      availability: availability,
      throwOnCheckAvailability: speechThrows,
    );
    final service = TranscriptionService(
      recorder: recorder,
      engine: engine,
      store: store,
      composer: FakeAudioComposer(),
    );
    return OnboardingCubit(service: service, scheduler: scheduler, notifier: notifier);
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

  test('a throwing mic request resets the spinner and stays retryable', () async {
    // A channel error is not an answer: the status must stay undetermined so
    // the next Next tap retries instead of a spinner stuck forever.
    final cubit = build(micThrows: true);
    await cubit.requestMic();
    expect(cubit.state.mic, PermissionStatus.undetermined);
    expect(cubit.state.requestingMic, isFalse);
    // The in-flight guard must not eat the retry.
    await cubit.requestMic();
    expect(cubit.state.requestingMic, isFalse);
    await cubit.close();
  });

  test('a throwing speech request resets the spinner and stays retryable', () async {
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

  test('requestPending answers both prompts in one pass', () async {
    final cubit = build();
    await cubit.requestPending(reminders: false);
    expect(cubit.state.micGranted, isTrue);
    expect(cubit.state.speechGranted, isTrue);
    expect(recorder.ensurePermissionCalls, 1);
    expect(engine.checkAvailabilityCalls, 1);
    await cubit.close();
  });

  test('requestPending skips prompts that already have an answer', () async {
    final cubit = build(mic: PermissionStatus.denied);
    await cubit.requestMic();
    await cubit.requestSpeech();
    await cubit.requestPending(reminders: false);
    expect(recorder.ensurePermissionCalls, 1);
    expect(engine.checkAvailabilityCalls, 1);
    await cubit.close();
  });

  test('a second requestPending while the mic prompt is up starts nothing over it', () async {
    final cubit = build();
    final prompt = recorder.permissionPrompt = Completer<void>();
    final first = cubit.requestPending(reminders: false);
    final second = cubit.requestPending(reminders: false);
    await Future<void>.delayed(Duration.zero);
    expect(engine.checkAvailabilityCalls, 0);
    prompt.complete();
    await Future.wait([first, second]);
    expect(recorder.ensurePermissionCalls, 1);
    expect(engine.checkAvailabilityCalls, 1);
    expect(cubit.state.micGranted, isTrue);
    expect(cubit.state.speechGranted, isTrue);
    await cubit.close();
  });

  test('requestPending still asks for speech after a failed mic prompt', () async {
    final cubit = build(micThrows: true);
    await cubit.requestPending(reminders: false);
    expect(cubit.state.mic, PermissionStatus.undetermined);
    expect(cubit.state.speechGranted, isTrue);
    await cubit.close();
  });

  test('reminders granted on the set-up page switch the reminders on', () async {
    final cubit = build();
    await cubit.requestReminders();
    await pumpEventQueue();
    expect(cubit.state.remindersGranted, isTrue);
    expect(ReflectionNotifier.masterEnabled(notify), isTrue);
    expect(scheduler.scheduled, isNotEmpty);
  });

  test('a refused reminders prompt stores nothing', () async {
    final cubit = build(grant: false);
    await cubit.requestReminders();
    expect(cubit.state.reminders, NotificationPermission.denied);
    expect(ReflectionNotifier.masterEnabled(notify), isFalse);
    expect(scheduler.scheduled, isEmpty);
  });

  test('the pending pass asks for reminders after the microphone and speech', () async {
    final cubit = build();
    await cubit.requestPending(reminders: true);
    expect(cubit.state.micGranted, isTrue);
    expect(cubit.state.speechGranted, isTrue);
    expect(scheduler.permissionRequests, 1);
  });

  test('a phone that cannot reflect is never asked for reminders', () async {
    final cubit = build();
    await cubit.requestPending(reminders: false);
    expect(scheduler.permissionRequests, 0);
    expect(cubit.state.reminders, NotificationPermission.notDetermined);
  });
}
