import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/audio/audio_player.dart';
import 'package:opentranscribe/core/audio/platform_audio_player.dart';
import 'package:opentranscribe/core/audio/platform_audio_recorder.dart';
import 'package:opentranscribe/core/routes/app_router.dart';
import 'package:opentranscribe/core/services/audio_storage_settings.dart';
import 'package:opentranscribe/core/services/entry_store.dart';
import 'package:opentranscribe/core/services/transcription_service.dart';
import 'package:opentranscribe/core/services/transcription_settings.dart';
import 'package:opentranscribe/core/transcribe/apple_speech_engine.dart';

const _devStorageKey = 'opentranscribe-dev-storage-key-0';

/// Compile-time storage encryption key.
///
/// Override at build time with a real secret and never commit one:
///
/// ```
/// flutter run --dart-define=STORAGE_KEY=<your-32-char-key>
/// ```
///
/// The fallback below is a development-only default so the app runs out of the
/// box. Nothing here ever leaves the device.
const _storageKey = String.fromEnvironment('STORAGE_KEY', defaultValue: _devStorageKey);

/// The app's dependency composition root.
///
/// A single global object with typed fields, built exactly once in
/// [Deps.init] during bootstrap and read from anywhere without a
/// `BuildContext`:
///
/// ```dart
/// final storage = Deps.i.localService;
/// final router = Deps.i.router;
/// ```
///
/// No service locator, no `get_it`, no code generation: dependencies are
/// plain, type-safe fields. Add a new dependency by giving it a field here and
/// constructing it in [init].
class Deps {
  const Deps._({
    required this.localService,
    required this.transcriptionService,
    required this.audioStorageSettings,
    required this.transcriptionSettings,
    required this.audioPlayer,
    required this.router,
  });

  /// The singleton instance. Valid only after [init] has completed.
  static late final Deps i;

  final LocalService localService;

  /// The one boundary the app talks to for recording and transcription. The
  /// recorder, engine, and store stay private inside it so the entry lifecycle
  /// has one owner and callers cannot bypass the on-device guard it enforces.
  final TranscriptionService transcriptionService;

  /// The audio-backup preference (excluded from iCloud/local backup by default).
  final AudioStorageSettings audioStorageSettings;

  /// The transcription language (device locale by default, user-overridable).
  final TranscriptionSettings transcriptionSettings;

  /// Plays back a kept recording. Pure playback; resolve an entry to a path with
  /// [TranscriptionService.resolveAudioPath] first.
  final AudioPlayer audioPlayer;
  final AppRouter router;

  /// Builds every dependency and installs the singleton. Called once, from
  /// bootstrap, before `runApp`.
  static Future<void> init() async {
    // Refuse to ship a release build that would encrypt journal data with the
    // committed development key. Provide a real key via --dart-define=STORAGE_KEY.
    if (kReleaseMode && _storageKey == _devStorageKey) {
      throw StateError('STORAGE_KEY must be supplied via --dart-define for a release build');
    }

    final localService = LocalService();
    await localService.init(encryptionKey: _storageKey);

    // One recorder instance for capture and the backup preference. The native
    // session is a singleton anyway, so there is no reason to build two.
    final recorder = PlatformAudioRecorder();
    final audioStorageSettings = AudioStorageSettings(storage: localService, recorder: recorder);
    await audioStorageSettings.apply();

    final transcriptionService = TranscriptionService(
      recorder: recorder,
      engine: AppleSpeechEngine(),
      store: EntryStore(localService),
    );
    final transcriptionSettings = TranscriptionSettings(
      storage: localService,
      service: transcriptionService,
    );
    // Pushes the stored (or device-default) language before anything records.
    transcriptionSettings.apply();

    i = Deps._(
      localService: localService,
      transcriptionService: transcriptionService,
      audioStorageSettings: audioStorageSettings,
      transcriptionSettings: transcriptionSettings,
      audioPlayer: PlatformAudioPlayer(),
      router: AppRouter(),
    );

    // Recover or remove audio files no entry references (a kill mid-recording, a
    // save that never landed). Off the critical path: launch must not wait on it.
    unawaited(i.transcriptionService.reconcileOrphans().catchError((Object _) => 0));
  }
}
