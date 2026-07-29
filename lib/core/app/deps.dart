import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/audio/audio_player.dart';
import 'package:opentranscribe/core/audio/platform_audio_player.dart';
import 'package:opentranscribe/core/audio/platform_audio_recorder.dart';
import 'package:opentranscribe/core/models/engine_descriptor.dart';
import 'package:opentranscribe/core/routes/app_router.dart';
import 'package:opentranscribe/core/services/audio_storage_settings.dart';
import 'package:opentranscribe/core/services/entry_store.dart';
import 'package:opentranscribe/core/services/transcription_service.dart';
import 'package:opentranscribe/core/services/transcription_settings.dart';
import 'package:opentranscribe/core/theming/app_icons.dart';
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
    required this.engineDescriptors,
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

  /// The engines this build ships, as presentation facts for surfaces that list
  /// them. Built here because the composition root is the one place allowed to
  /// name an engine.
  final List<EngineDescriptor> engineDescriptors;

  /// Builds every dependency and installs the singleton. Called once, from
  /// bootstrap, before `runApp`.
  static bool _initialized = false;

  static Future<void> init() async {
    // Idempotent: a stray second call after a successful init would otherwise
    // throw an opaque LateInitializationError on the `i` assignment. The flag is
    // set only once `i` is assigned (end of this method), so a call that threw
    // partway can still be retried rather than early-returning with `i` unset.
    if (_initialized) return;

    // Refuse to ship a release build that would encrypt journal data with the
    // committed development key. Provide a real key via --dart-define=STORAGE_KEY.
    if (kReleaseMode && _storageKey == _devStorageKey) {
      throw StateError('STORAGE_KEY must be supplied via --dart-define for a release build');
    }
    if (kDebugMode && _storageKey == _devStorageKey) {
      debugPrint('deps: using the committed development STORAGE_KEY (debug/profile only)');
    }

    final localService = LocalService();
    await localService.init(encryptionKey: _storageKey);

    // One recorder instance for capture and the backup preference. The native
    // session is a singleton anyway, so there is no reason to build two.
    final recorder = PlatformAudioRecorder();
    // End any capture the NATIVE session is still running. Dart's state can
    // restart while the platform singleton does not (a hot restart in
    // development), and a session left hot fails every later start with
    // "already recording" until the app is relaunched. Quiet when idle, which
    // is every real launch.
    unawaited(
      recorder.cancel().catchError((Object e) {
        if (kDebugMode) debugPrint('deps: launch cancel of a stale capture failed: $e');
      }),
    );
    final audioStorageSettings = AudioStorageSettings(storage: localService, recorder: recorder);
    await audioStorageSettings.apply();

    final engine = AppleSpeechEngine();
    // Built before the service so a fresh recording's wave shape can be read
    // and persisted at save time (viewing then never re-decodes the file).
    final audioPlayer = PlatformAudioPlayer();
    final transcriptionService = TranscriptionService(
      recorder: recorder,
      engine: engine,
      store: EntryStore(localService),
      peaksReader: (path) => audioPlayer.peaks(path, buckets: AudioPlayer.defaultPeakBuckets),
      keepAudio: () => audioStorageSettings.keepAudio,
    );
    final transcriptionSettings = TranscriptionSettings(
      storage: localService,
      service: transcriptionService,
    );
    // Pushes the stored (or resolved device-default) language before anything
    // records.
    await transcriptionSettings.apply();

    i = Deps._(
      localService: localService,
      transcriptionService: transcriptionService,
      audioStorageSettings: audioStorageSettings,
      transcriptionSettings: transcriptionSettings,
      audioPlayer: audioPlayer,
      router: AppRouter(),
      // The models screen renders this registry; whisper.cpp lands as one
      // more entry here, not new plumbing.
      engineDescriptors: [
        EngineDescriptor(
          engineId: engine.id,
          displayName: 'Apple Speech',
          logo: AppIcons.appleLogo,
        ),
      ],
    );
    _initialized = true;

    // Recover or remove audio files no entry references (a kill mid-recording, a
    // save that never landed). Off the critical path: launch must not wait on it.
    // The heal then repairs records whose audio file is already gone (a kill
    // mid-discard); chained after the sweep so the two never interleave over one
    // directory. NEVER a bulk purge here: deleting kept history is the Cache
    // screen's explicit, confirmed action, and a toggle flip must not schedule it.
    unawaited(
      i.transcriptionService
          .reconcileOrphans()
          .then((_) => i.transcriptionService.healDanglingAudio())
          .catchError((Object e) {
            if (kDebugMode) debugPrint('deps: launch audio sweep failed: $e');
            return 0;
          }),
    );
  }
}
