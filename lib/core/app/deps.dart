import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:opentranscribe/core/app/app_language.dart';
import 'package:opentranscribe/core/app/engine_registry.dart';
import 'package:opentranscribe/core/app/launch_backdrop.dart';
import 'package:opentranscribe/core/app/local_service.dart';
import 'package:opentranscribe/core/app/splash_handoff.dart';
import 'package:opentranscribe/core/app/storage_key.dart';
import 'package:opentranscribe/core/export/default_exporter.dart';
import 'package:opentranscribe/core/export/html_exporter.dart';
import 'package:opentranscribe/core/export/journal_exporter.dart';
import 'package:opentranscribe/core/export/obsidian_exporter.dart';
import 'package:opentranscribe/core/export/share_export.dart';
import 'package:opentranscribe/core/export/staging_registry.dart';
import 'package:opentranscribe/core/intents/intent_action_service.dart';
import 'package:opentranscribe/core/intents/intent_actions.dart';
import 'package:opentranscribe/core/models/engine_descriptor.dart';
import 'package:opentranscribe/core/models/exporter_descriptor.dart';
import 'package:opentranscribe/core/notify/notification_scheduler.dart';
import 'package:opentranscribe/core/notify/reflection_notifier.dart';
import 'package:opentranscribe/core/routes/app_router.dart';
import 'package:opentranscribe/core/routes/routes.dart';
import 'package:opentranscribe/core/services/audio_storage_settings.dart';
import 'package:opentranscribe/core/services/backup_settings.dart';
import 'package:opentranscribe/core/services/engine_settings.dart';
import 'package:opentranscribe/core/services/entry_store.dart';
import 'package:opentranscribe/core/services/export_service.dart';
import 'package:opentranscribe/core/services/import_service.dart';
import 'package:opentranscribe/core/services/notification_settings.dart';
import 'package:opentranscribe/core/services/reflection_service.dart';
import 'package:opentranscribe/core/services/reflection_settings.dart';
import 'package:opentranscribe/core/services/reflection_store.dart';
import 'package:opentranscribe/core/services/support_service.dart';
import 'package:opentranscribe/core/services/transcription_service.dart';
import 'package:opentranscribe/core/services/transcription_settings.dart';
import 'package:opentranscribe/core/support/support_store.dart';
import 'package:opentranscribe/core/theming/app_icons.dart';
import 'package:opentranscribe/core/utils/thermal.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:reflections/reflections.dart';
import 'package:transcriber/transcriber.dart';

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
    required this.engineRegistry,
    required this.engineSettings,
    required this.exportService,
    required this.importService,
    required this.stagingRegistry,
    required this.backupSettings,
    required this.exporterDescriptors,
    required this.intentActionService,
    required this.splashHandoff,
    required this.launchBackdrop,
    required this.supportService,
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

  /// Serves the actions a system surface submits (the lock screen control and
  /// widget row, Control Center, the Action button, Shortcuts, Siri). Served
  /// once the first frames are up, and drained again on resume; see
  /// [IntentActionService.serve].
  final IntentActionService intentActionService;

  /// Takes the native launch splash down once home has painted.
  final SplashHandoff splashHandoff;

  /// Mirrors the theme's launch colours where that splash can read them.
  final LaunchBackdrop launchBackdrop;

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

  /// The engines this build ships, in preference order: descriptor, instance,
  /// and this device's availability per entry. Built here because the
  /// composition root is the one place allowed to name an engine; every engine
  /// surface iterates this registry and nothing else, so a new engine is one
  /// more entry here.
  final List<EngineEntry> engineRegistry;

  /// The persisted engine choice; unset means auto (the first available
  /// registry entry).
  final EngineSettings engineSettings;

  /// Stages exports (entry, journal, native archive) and hands them to the
  /// share sheet. Read-only with respect to journal state.
  final ExportService exportService;

  /// Restores a native archive through the lifecycle owners; a failed import
  /// changes nothing.
  final ImportService importService;

  /// Which staging directories [exportService] and [importService] currently
  /// own, so [launchMaintenance]'s sweep never deletes one still in flight.
  final StagingRegistry stagingRegistry;

  /// The Backup surface's persisted choices (format, seal, last archive).
  final BackupSettings backupSettings;

  /// The export formats this build ships, as presentation facts for the
  /// format pickers. Built here because the composition root is the one place
  /// allowed to name an exporter, mirroring [engineRegistry].
  final List<ExporterDescriptor> exporterDescriptors;

  /// The one owner of the supporter answer (the paid entitlement). Reads its
  /// cached tier synchronously at construction; no store channel is awaited
  /// on the launch path, and [launchMaintenance] refreshes it off-frame.
  final SupportService supportService;

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

    // Debug is the only mode that may run on the committed development key: a
    // profile build lands on real devices against real journals, the same as
    // release. Provide a real key via --dart-define=STORAGE_KEY.
    if (!kDebugMode && _storageKey == _devStorageKey) {
      throw StateError('STORAGE_KEY must be supplied via --dart-define for a non-debug build');
    }
    if (kDebugMode && _storageKey == _devStorageKey) {
      debugPrint('deps: using the committed development STORAGE_KEY (debug only)');
    }

    // The device key must never fall back to null once obtain() has run once
    // on this device: a device that has migrated to v3 would otherwise read
    // as an empty journal instead of failing loudly. Let a Keychain failure
    // throw; bootstrap surfaces it.
    final deviceKey = await StorageKey().obtain().timeout(_channelTimeout);

    final localService = LocalService();
    await localService.init(
      legacyKey: _storageKey,
      deviceKey: deviceKey,
      channelTimeout: _channelTimeout,
    );

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

    final speechEngine = AppleSpeechEngine();
    final dictationEngine = AppleDictationEngine();
    // One availability probe decides the analyzer entry; the native side
    // resolves it once per process behind its own deadline, so a wedged
    // catalog query answers unavailable instead of holding this timeout.
    final analyzerAvailable = await speechEngine.analyzerAvailable().timeout(
      _channelTimeout,
      onTimeout: () => false,
    );
    // Preference order: the registry's first available entry is the auto
    // default. A future engine (whisper.cpp) is one more entry here.
    final engineRegistry = <EngineEntry>[
      EngineEntry(
        descriptor: EngineDescriptor(
          engineId: speechEngine.id,
          displayName: 'SpeechAnalyzer',
          blurb: (l10n) => l10n.engineBlurbSpeechAnalyzer,
          logo: AppIcons.appleLogo,
        ),
        engine: speechEngine,
        available: analyzerAvailable,
        unavailability: analyzerAvailable ? null : EngineUnavailability.needsNewerDevice,
      ),
      EngineEntry(
        descriptor: EngineDescriptor(
          engineId: dictationEngine.id,
          displayName: 'Dictation',
          blurb: (l10n) => l10n.engineBlurbDictation,
          logo: AppIcons.appleLogo,
        ),
        engine: dictationEngine,
        available: true,
      ),
    ];
    final engineSettings = EngineSettings(storage: localService);
    // Built before the service so a fresh recording's wave shape can be read
    // and persisted at save time (viewing then never re-decodes the file).
    final audioPlayer = PlatformAudioPlayer();
    // Hoisted so both the transcription lifecycle and the reflection lifecycle
    // read the same entries; the store is stateless, so sharing one is safe.
    final entryStore = EntryStore(localService);
    // Costs the launch a channel listen; the bulk re-transcribe queue reads
    // the cached answer between entries.
    final thermalMonitor = ThermalMonitor()..start();
    final transcriptionService = TranscriptionService(
      recorder: recorder,
      engine: engineSettings.resolveActive(engineRegistry).engine,
      store: entryStore,
      peaksReader: (path) => audioPlayer.peaks(path, buckets: AudioPlayer.defaultPeakBuckets),
      keepAudio: () => audioStorageSettings.keepAudio,
      thermalPressure: () => thermalMonitor.underPressure,
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

    // The support backbone. The one place naming the product, like engines
    // and exporters. Constructed from the cached tier alone; the first store
    // round trip is launchMaintenance's refresh, never the launch path.
    final supportService = SupportService(
      storage: localService,
      store: SupportStore(),
      lifetimeId: 'xyz.opentranscribe.supporter.lifetime',
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
    final stagingRegistry = StagingRegistry();
    final exportService = ExportService(
      transcription: transcriptionService,
      reflections: reflectionService,
      exporters: exporters,
      share: shareExport,
      appVersion: () async => appVersion ??= (await PackageInfo.fromPlatform()).version,
      staging: stagingRegistry,
      isSupporter: () => supportService.tier.isSupporter,
    );
    final importService = ImportService(
      transcription: transcriptionService,
      reflections: reflectionService,
      share: shareExport,
      staging: stagingRegistry,
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
      engineRegistry: engineRegistry,
      engineSettings: engineSettings,
      exportService: exportService,
      importService: importService,
      stagingRegistry: stagingRegistry,
      backupSettings: backupSettings,
      // Lazy closures on purpose: nothing here touches the router's config
      // until an action actually arrives, so wiring this costs the launch
      // nothing.
      intentActionService: IntentActionService(
        source: PlatformIntentActions(),
        canOpenRecorder: () => router.recorderCanOpen,
        openRecorder: () => router.config.pushNamed(Routes.recordName),
      ),
      splashHandoff: SplashHandoff(),
      launchBackdrop: LaunchBackdrop(),
      supportService: supportService,
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
  /// next call runs every pass again, whenever the audio sweep did not
  /// walk the whole directory: a capture was live or finalizing, or the sweep
  /// threw. An orphan it did not reach is invisible to every surface until some
  /// pass recovers it, and the reflection passes are individually single-flight,
  /// so repeating them costs nothing.
  ///
  /// The passes run concurrently, and only the sweep is awaited. Two reasons in
  /// one: a wedged file probe must not hold the reflection catch-up and the
  /// notification sync for the process lifetime, and a reflection generation
  /// (minutes, several periods deep) must not hold the sweep's retry, which is
  /// the failure the re-arm exists to fix. A wedged probe leaves this future
  /// pending, so nothing re-arms in a loop.
  ///
  /// The returned future therefore means "the audio sweep settled", not
  /// "every pass finished". Both callers fire it unawaited.
  static Future<void> launchMaintenance() => _maintenance ??= _maintain();

  static Future<void> _maintain() async {
    unawaited(_quietly('reflection catch-up', () => i.reflectionService.catchUp()));
    unawaited(_quietly('notification sync', () => i.reflectionNotifier.sync()));
    // Fire-and-forget: entitlement staleness costs a locked format at worst,
    // and the cached tier already answered the launch.
    unawaited(_quietly('supporter refresh', () => i.supportService.refresh()));
    // Warm the price so the support screen's join button renders at once
    // instead of waiting on StoreKit when the user opens it.
    unawaited(_quietly('supporter price', () => i.supportService.warmProduct()));
    // Fire-and-forget, like the passes above: a stale staging directory
    // costs disk, not correctness, so it must not gate the re-arm below.
    unawaited(_quietly('staging sweep', _sweepStaging));
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

  /// Deletes stale `import-`/`export-` staging directories left behind by a
  /// crash, jetsam kill, or force-quit mid-operation: the whole plaintext
  /// journal can sit in one until this runs. [StagingRegistry.sweep] holds
  /// the actual logic so it stays testable without constructing [Deps].
  static Future<void> _sweepStaging() => i.stagingRegistry.sweep(Directory.systemTemp);

  static Future<T?> _quietly<T>(String what, Future<T> Function() run) async {
    try {
      return await run();
    } catch (e) {
      if (kDebugMode) debugPrint('deps: launch $what failed: $e');
      return null;
    }
  }
}
