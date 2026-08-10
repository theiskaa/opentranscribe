import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:opentranscribe/core/app/app_language.dart';
import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/app/storage_key.dart';
import 'package:opentranscribe/core/audio/audio_player.dart';
import 'package:opentranscribe/core/audio/platform_audio_player.dart';
import 'package:opentranscribe/core/audio/platform_audio_recorder.dart';
import 'package:opentranscribe/core/export/default_exporter.dart';
import 'package:opentranscribe/core/export/html_exporter.dart';
import 'package:opentranscribe/core/export/journal_exporter.dart';
import 'package:opentranscribe/core/export/obsidian_exporter.dart';
import 'package:opentranscribe/core/export/share_export.dart';
import 'package:opentranscribe/core/models/engine_descriptor.dart';
import 'package:opentranscribe/core/intents/intent_action_service.dart';
import 'package:opentranscribe/core/intents/intent_actions.dart';
import 'package:opentranscribe/core/models/exporter_descriptor.dart';
import 'package:opentranscribe/core/notify/notification_scheduler.dart';
import 'package:opentranscribe/core/notify/reflection_notifier.dart';
import 'package:opentranscribe/core/reflect/foundation_models_engine.dart';
import 'package:opentranscribe/core/routes/app_router.dart';
import 'package:opentranscribe/core/routes/routes.dart';
import 'package:opentranscribe/core/services/audio_storage_settings.dart';
import 'package:opentranscribe/core/services/backup_settings.dart';
import 'package:opentranscribe/core/services/entry_store.dart';
import 'package:opentranscribe/core/services/export_service.dart';
import 'package:opentranscribe/core/services/import_service.dart';
import 'package:opentranscribe/core/services/notification_settings.dart';
import 'package:opentranscribe/core/services/reflection_service.dart';
import 'package:opentranscribe/core/services/reflection_settings.dart';
import 'package:opentranscribe/core/services/reflection_store.dart';
import 'package:opentranscribe/core/services/transcription_service.dart';
import 'package:opentranscribe/core/services/transcription_settings.dart';
import 'package:opentranscribe/core/theming/app_icons.dart';
import 'package:opentranscribe/core/transcribe/apple_speech_engine.dart';
import 'package:opentranscribe/core/utils/launch_trace.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
    required this.reflectionService,
    required this.reflectionSettings,
    required this.notificationScheduler,
    required this.notificationSettings,
    required this.reflectionNotifier,
    required this.engineDescriptors,
    required this.exportService,
    required this.importService,
    required this.backupSettings,
    required this.exporterDescriptors,
    required this.intentActionService,
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

  /// Serves the actions a system surface submits (the lock screen control,
  /// Control Center, the Action button, Shortcuts, Siri). Served once the first
  /// frames are up, and drained again on resume; see [IntentActionService.serve].
  final IntentActionService intentActionService;

  /// The one owner of the weekly-reflection lifecycle: when a week closes, it
  /// reads the week back on-device. Keeps its engine and store private, like
  /// [TranscriptionService]: history and availability are read through it, so
  /// nothing can bypass the on-device guard or the silence-is-a-result rule.
  final ReflectionService reflectionService;

  /// The reflection preferences (on/off, voice, length, specificity), plus the
  /// service-recorded no-backfill floor.
  final ReflectionSettings reflectionSettings;

  /// Local, on-device notification scheduling. Generic: it names no feature, so
  /// a surface asks it for permission and drives it through the notifier below.
  final NotificationScheduler notificationScheduler;

  /// The local-notification preferences (the weekly reflection nudge and its
  /// fire time). Generic, like [notificationScheduler].
  final NotificationSettings notificationSettings;

  /// The one reflection-aware piece: it decides when the weekly nudge should be
  /// scheduled and reconciles the OS's pending notification with the settings.
  /// Driven by [ReflectionNotifier.sync] at launch, on resume, and after a
  /// settings change.
  final ReflectionNotifier reflectionNotifier;

  /// The engines this build ships, as presentation facts for surfaces that list
  /// them. Built here because the composition root is the one place allowed to
  /// name an engine.
  final List<EngineDescriptor> engineDescriptors;

  /// Stages exports (entry, journal, native archive) and hands them to the
  /// share sheet. Read-only with respect to journal state.
  final ExportService exportService;

  /// Restores a native archive through the lifecycle owners; a failed import
  /// changes nothing.
  final ImportService importService;

  /// The Backup surface's persisted choices (format, seal, last archive).
  final BackupSettings backupSettings;

  /// The export formats this build ships, as presentation facts for the
  /// format pickers. Built here because the composition root is the one place
  /// allowed to name an exporter, mirroring [engineDescriptors].
  final List<ExporterDescriptor> exporterDescriptors;

  /// How long any ONE platform-channel round trip below may take before
  /// startup gives up on it.
  ///
  /// Per channel, not around the whole of [init]: the hang this exists to catch
  /// is a native handler that never calls `result` (iOS 26's
  /// `SpeechTranscriber.supportedLocales` did exactly that), which no catch can
  /// see. Applied to every channel [init] awaits, including opening the
  /// encrypted store. The one step deliberately left outside it is the legacy
  /// storage migration, which rewrites every record on the single launch after
  /// an upgrade: that work always finishes, and a large journal can take
  /// seconds, so a deadline around it would fail the one launch doing exactly
  /// the right thing. Far short of the ~20 s iOS watchdog either way, so a
  /// wedged channel lands on the failure screen instead of as a launch kill
  /// with no frame at all.
  static const _channelTimeout = Duration(seconds: 8);

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

    // The device key must never fall back to null once obtain() has run once
    // on this device: a device that has migrated to v3 would otherwise read
    // as an empty journal instead of failing loudly. Let a Keychain failure
    // throw; bootstrap surfaces it.
    final deviceKey = await StorageKey().obtain().timeout(_channelTimeout);
    LaunchTrace.mark('  keychain'); // TEMP

    final localService = LocalService();
    await localService.init(
      legacyKey: _storageKey,
      deviceKey: deviceKey,
      channelTimeout: _channelTimeout,
    );
    LaunchTrace.mark('  storage read'); // TEMP

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
    // Abandoned, not thrown, on a wedged channel: apply() already swallows its
    // own failures, and exclusion is a PERSISTED filesystem attribute, so
    // skipping the push leaves the directory on whatever it was last given
    // (excluded, until the user opted in). A timeout must not be the one way
    // this preference kills a launch.
    await audioStorageSettings.apply().timeout(
      _channelTimeout,
      // Logged like apply()'s own catch: a persistent failure silently drops
      // the user's backup opt-in.
      onTimeout: () {
        if (kDebugMode) debugPrint('deps: the audio backup preference timed out');
      },
    );
    LaunchTrace.mark('  audio settings'); // TEMP

    final engine = AppleSpeechEngine();
    // Built before the service so a fresh recording's wave shape can be read
    // and persisted at save time (viewing then never re-decodes the file).
    final audioPlayer = PlatformAudioPlayer();
    // Hoisted so both the transcription lifecycle and the reflection lifecycle
    // read the same entries; the store is stateless, so sharing one is safe.
    final entryStore = EntryStore(localService);
    final transcriptionService = TranscriptionService(
      recorder: recorder,
      engine: engine,
      store: entryStore,
      peaksReader: (path) => audioPlayer.peaks(path, buckets: AudioPlayer.defaultPeakBuckets),
      keepAudio: () => audioStorageSettings.keepAudio,
    );
    final transcriptionSettings = TranscriptionSettings(
      storage: localService,
      service: transcriptionService,
    );
    // Pushes the stored (or resolved device-default) language before anything
    // records. Allowed to throw on timeout: an engine that never answers what
    // it can transcribe is a broken speech channel, and a diagnosable failure
    // screen beats an app whose only feature silently does nothing.
    await transcriptionSettings.apply().timeout(_channelTimeout);
    LaunchTrace.mark('  speech settings'); // TEMP

    // The reflection backbone. FoundationModelsEngine is the ONE place naming
    // Foundation Models; the service refuses it if it is not on-device. Nothing
    // is generated here: catchUp runs off the critical path below.
    final reflectionEngine = FoundationModelsEngine();
    final reflectionSettings = ReflectionSettings(storage: localService);
    final reflectionStore = ReflectionStore(localService);
    final reflectionService = ReflectionService(
      engine: reflectionEngine,
      store: reflectionStore,
      settings: reflectionSettings,
      entries: entryStore.all,
      language: () => AppLanguage.of(localService),
    );

    // The notification backbone. The scheduler and settings are generic; the
    // notifier holds the reflection-only policy. It probes the engine's
    // availability directly (not through the service) so it stays decoupled
    // from the entry lifecycle.
    final notificationSettings = NotificationSettings(storage: localService);
    final notificationScheduler = PlatformNotificationScheduler();
    final reflectionNotifier = ReflectionNotifier(
      scheduler: notificationScheduler,
      notifySettings: notificationSettings,
      reflectionSettings: reflectionSettings,
      availability: reflectionEngine.availability,
      language: () => AppLanguage.of(localService),
    );

    // The backup backbone. The one place allowed to name a concrete exporter,
    // like the engine rule; a new format lands as one entry here plus its
    // descriptor below, not new plumbing.
    final shareExport = ShareExport();
    const defaultExporter = DefaultExporter();
    const obsidianExporter = ObsidianExporter();
    const htmlExporter = HtmlExporter();
    final exporters = <String, JournalExporter>{
      for (final e in const <JournalExporter>[defaultExporter, obsidianExporter, htmlExporter])
        e.id: e,
    };
    final backupSettings = BackupSettings(
      storage: localService,
      fallbackFormatId: defaultExporter.id,
    );
    String? appVersion;
    final exportService = ExportService(
      transcription: transcriptionService,
      reflections: reflectionService,
      exporters: exporters,
      share: shareExport,
      appVersion: () async => appVersion ??= (await PackageInfo.fromPlatform()).version,
    );
    final importService = ImportService(
      transcription: transcriptionService,
      reflections: reflectionService,
      share: shareExport,
    );

    final router = AppRouter();

    i = Deps._(
      localService: localService,
      transcriptionService: transcriptionService,
      audioStorageSettings: audioStorageSettings,
      transcriptionSettings: transcriptionSettings,
      audioPlayer: audioPlayer,
      router: router,
      reflectionService: reflectionService,
      reflectionSettings: reflectionSettings,
      notificationScheduler: notificationScheduler,
      notificationSettings: notificationSettings,
      reflectionNotifier: reflectionNotifier,
      // The models screen renders this registry; whisper.cpp lands as one
      // more entry here, not new plumbing.
      engineDescriptors: [
        EngineDescriptor(
          engineId: engine.id,
          displayName: 'Apple Speech',
          logo: AppIcons.appleLogo,
        ),
      ],
      exportService: exportService,
      importService: importService,
      backupSettings: backupSettings,
      // Lazy closures on purpose: nothing here touches the router's config
      // until an action actually arrives, so wiring this costs the launch
      // nothing.
      intentActionService: IntentActionService(
        source: PlatformIntentActions(),
        canOpenRecorder: () => router.recorderCanOpen,
        openRecorder: () => router.config.pushNamed(Routes.recordName),
      ),
      exporterDescriptors: [
        ExporterDescriptor(
          exporterId: defaultExporter.id,
          format: ExportFormat.markdown,
          logo: 'assets/brand/markdown.svg',
        ),
        ExporterDescriptor(
          exporterId: obsidianExporter.id,
          format: ExportFormat.obsidian,
          logo: 'assets/brand/obsidian.svg',
        ),
        ExporterDescriptor(
          exporterId: htmlExporter.id,
          format: ExportFormat.web,
          logo: 'assets/brand/safari.svg',
        ),
      ],
    );
    LaunchTrace.mark('  wiring'); // TEMP
    _initialized = true;
  }

  static Future<void>? _maintenance;

  /// Launch repair and catch-up, deliberately NOT part of [init].
  ///
  /// Every one of these reads the whole journal, and [EntryStore] decrypts each
  /// record on the way out, so each pass costs milliseconds per entry on the UI
  /// isolate. Running them while the first frames are being built is what makes
  /// those frames slow, so the caller must not call this until the first frames
  /// are committed.
  ///
  /// Single-flight, never throws, and safe to call on every foreground: it does
  /// its work once and afterwards returns the same future. It re-arms, so the
  /// next call runs ALL THREE passes again, whenever the audio sweep did not
  /// walk the whole directory: a capture was live or finalizing, or the sweep
  /// threw. An orphan it did not reach is invisible to every surface until some
  /// pass recovers it, and the reflection passes are individually single-flight,
  /// so repeating them costs nothing.
  ///
  /// The three run concurrently, and only the sweep is awaited. Two reasons in
  /// one: a wedged file probe must not hold the reflection catch-up and the
  /// notification sync for the process lifetime, and a reflection generation
  /// (minutes, several periods deep) must not hold the sweep's retry, which is
  /// the failure the re-arm exists to fix. A wedged probe leaves this future
  /// pending, so nothing re-arms in a loop.
  ///
  /// The returned future therefore means "the audio sweep settled", not "all
  /// three finished". Both callers fire it unawaited.
  static Future<void> launchMaintenance() => _maintenance ??= _maintain();

  static Future<void> _maintain() async {
    unawaited(_quietly('reflection catch-up', () => i.reflectionService.catchUp()));
    unawaited(_quietly('notification sync', () => i.reflectionNotifier.sync()));
    // Null, not false: `_quietly` answers null when the sweep threw, which is
    // no proof the directory was walked either.
    if ((await _quietly('audio sweep', _sweepAudio)) != true) _maintenance = null;
  }

  /// Recovers or removes audio files no entry references (a kill mid-recording,
  /// a save that never landed), then repairs records whose audio file is already
  /// gone (a kill mid-discard). The heal runs after the sweep so the two never
  /// interleave over one directory. NEVER a bulk purge here: deleting kept
  /// history is the Cache screen's explicit, confirmed action.
  ///
  /// False when a capture blocked the sweep from walking the whole directory.
  /// The heal still runs: it repairs a transcribed record whose file is ALREADY
  /// gone, which is true or not regardless of whether the directory was walked,
  /// and it never deletes a file, so a live capture makes it neither wrong nor
  /// unsafe. Only the sweep's own answer drives the re-arm above.
  static Future<bool> _sweepAudio() async {
    final swept = await i.transcriptionService.reconcileOrphans();
    await i.transcriptionService.healDanglingAudio();
    return swept != null;
  }

  static Future<T?> _quietly<T>(String what, Future<T> Function() run) async {
    try {
      return await run();
    } catch (e) {
      if (kDebugMode) debugPrint('deps: launch $what failed: $e');
      return null;
    }
  }
}
