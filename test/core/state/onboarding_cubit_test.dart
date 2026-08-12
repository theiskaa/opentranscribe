import 'package:flutter_test/flutter_test.dart';
import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/audio/recording.dart';
import 'package:opentranscribe/core/services/entry_store.dart';
import 'package:opentranscribe/core/services/transcription_service.dart';
import 'package:opentranscribe/core/state/onboarding_cubit.dart';
import 'package:opentranscribe/core/transcribe/fake_engine.dart';
import 'package:opentranscribe/core/transcribe/transcription_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_audio_recorder.dart';

void main() {
  late LocalService storage;
  late EntryStore store;
  late FakeAudioRecorder recorder;
  late FakeStreamingEngine engine;

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
  }) {
    recorder = FakeAudioRecorder(permission: mic, throwOnEnsurePermission: micThrows);
    engine = FakeStreamingEngine(
      availability: availability,
      throwOnCheckAvailability: speechThrows,
    );
    final service = TranscriptionService(recorder: recorder, engine: engine, store: store);
    return OnboardingCubit(service: service);
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
    await cubit.requestPending();
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
    await cubit.requestPending();
    expect(recorder.ensurePermissionCalls, 1);
    expect(engine.checkAvailabilityCalls, 1);
    await cubit.close();
  });

  test('requestPending still asks for speech after a failed mic prompt', () async {
    final cubit = build(micThrows: true);
    await cubit.requestPending();
    expect(cubit.state.mic, PermissionStatus.undetermined);
    expect(cubit.state.speechGranted, isTrue);
    await cubit.close();
  });
}
