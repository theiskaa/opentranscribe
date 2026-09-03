# opentranscribe

## Memory

Your memory is OptMem:

- The tool is `~/.optmem/memo`
- Your memories are in `~/.optmem/memory`

OptMem outlives every session, compaction, model and vendor change.
Without it you do not know who you are, or what was decided and tried.

### At startup: activating OptMem (mandatory)

Run `~/.optmem/memo wake` before any other tool call, in every session, and
then do exactly what it prints, to the end of its output.

### While working: register memories (mandatory)

Call `~/.optmem/memo note "<1 line, max 280 chars>"` whenever you learn
something new, or something worth keeping happens. That covers a task
worth real effort, a fact or insight the user teaches you, anything you
learn about their life (even indirectly), any event of lasting effect.

Do not register redundant memories.

If `~/.optmem/memo note` asks a compression: do it before your next action.

Never edit or delete anything under `~/.optmem/memory`: the tool manages it.

### When you need an old memory: search, or navigate

`~/.optmem/memo recall <regex>` searches every memory, word for word.

Your memories also form a binary tree: #0-1, #2-3 ... exist as one-line
summaries, pairs of those as #0-3, and so on -- every `#a-b` line wake
prints is one node of it. `~/.optmem/memo zoom <a-b>` opens a node into its
two halves, down to the raw memories.

### If you're a subagent: skip everything above

## What this is

A private, offline voice journal. You speak your mind, it writes it down, and it stays on your device. Flutter, iOS-first, no other platform is supported today.

## The one rule

**Nothing leaves the phone.** No network calls, no accounts, no analytics, no third-party SDK that phones home. The app must work fully in airplane mode. This is not a feature, it is the architecture, and it constrains every decision below. If a change would open a socket or ship data off-device, it does not belong here.

Corollaries that shape the code:

- Transcription runs on-device, behind one contract: `TranscriptionEngine` in `packages/transcriber`. Two engines ship, user-switchable on the transcription screen: `AppleSpeechEngine` (the iOS 26 SpeechAnalyzer, with managed model downloads) and `AppleDictationEngine` (the classic recognizer behind iOS dictation); whisper.cpp lands later as one more registry entry. Streaming and downloadable-model behavior are separate interfaces an engine may also implement, not flags: `StreamingTranscriptionEngine`, `ManagedModelEngine`.
- `TranscriptionEngine.onDeviceOnly` is a hard gate. The app refuses an engine that answers false, so nothing can quietly route audio off the phone.
- Nothing in `view/`, `core/services/`, or `core/state/` names a concrete engine. `Deps.init()` is the only place allowed to, plus the engine registry it builds (`EngineEntry` list in `core/app/engine_registry.dart`) for every surface that lists engines: registry order is preference order, auto mode runs the first available entry, and the stored choice lives in `EngineSettings`.
- Audio capture is recorder-owned, not engine-owned. Buffers stay native; only paths, durations, levels and text cross a channel. Raw audio for each entry is kept on-device by default so entries can be re-transcribed later by a better engine. Keeping is a preference: with keep-audio off, a recording is deleted after its first successful transcription and the entry becomes transcript-only (`Entry.audioPath` is nullable). Bulk reclaim of kept history is only ever the Cache screen's explicit, confirmed action.
- Continuing an entry records a normal take and merges it onto the kept file natively through `AudioComposer`; the merged file replaces the old one only after the entry is saved. The new words are stitched onto what the entry reads as; a base never transcribed gets one pass over the merged file instead, and one without a recording takes the take as its file, its old words untimed.
- The supporter purchase is direct StoreKit 2 (`SupportStore.swift` under `ios/Runner/`, wrapped by `core/support/`), no third-party purchase SDK and no server. The OS talks to the App Store; no journal content is in that conversation, entitlements are verified on-device from StoreKit's own record, and only the act of buying needs a connection. The club gates looks only; no function is ever gated, and `test/core/no_club_gate_test.dart` keeps it that way: nothing under `core/services/` or `core/state/` may ask for the tier except the support, theme, and app icon holders.

## Architecture

Two layers only. There is no `features/` layer, and we do not want one.

`lib/core/`, everything non-UI:

- `core/app/`: composition root (`deps.dart`), encrypted on-device storage (`local_service.dart`), locale source of truth (`app_language.dart`), the onboarding flag (`onboarding.dart`; a finished user re-enters the flow only as `/onboarding?replay=true`, which nothing links to today) and the one-shot hint flags (`hints.dart`, each shown once, ever).
- `core/export/`: the `JournalExporter` contract and the shipped format exporters, plus the native archive: store-only zip codec, manifest, sealed-container crypto, and the share-sheet channel wrapper.
- `core/models/`: plain data (`entry.dart`, `engine_descriptor.dart`, `exporter_descriptor.dart`, `reflection.dart`, `reflection_timeline.dart`).
- `core/routes/`: `app_router.dart` (the `GoRouter`), `routes.dart` (path and name constants), page transitions.
- `core/services/`: `transcription_service.dart` (the one owner of the entry lifecycle, capture through continuation landings, keeping recorder, composer, engine and store private inside it), `transcript_stitch.dart` (the pure stitch of a continued transcript), `entry_store.dart`, `support_service.dart` (the one owner of the supporter answer), and the settings holders.
- `core/support/`: the supporter entitlement's vocabulary and channel boundary: `SupporterTier`, `StoreProduct`, and the `SupportStore` wrapper over `opentranscribe/support`.
- `core/state/`: one cubit per concern.
- `core/theming/`: `AppTheme` and its tokens, `AppIcons`, motion, shapes, type scale.
- `core/notify/`: the local notification scheduler and the reflection reminders.
- `core/intents/`: actions from a system surface (the lock screen control, Siri, Shortcuts) routed to the recorder.
- `core/utils/`: haptics, platform capability probes, small helpers.

`lib/view/`, everything UI:

- `view/app.dart`: the root `App` widget (`WidgetsApp.router`, no Material or Cupertino app shell), which provides the cubits above the router.
- `view/launch_failure_app.dart`: the other root, handed to `runApp` when `Deps.init()` throws. It stands beside `app.dart` because it must reach no cubit, router, or storage: those are what failed.
- `view/layouts/<domain>/screens/<name>_screen.dart`: full screens, `<Name>Screen` class names.
- `view/layouts/<domain>/components/`: widgets private to that domain.
- `view/widgets/`: the shared, reusable widget set (the design system).

`lib/main.dart` and `lib/bootstrap.dart` sit at the root; `bootstrap` calls `Deps.init()` then `runApp`. `lib/l10n/` holds the `.arb` files and generated localizations.

`packages/` holds the plugins the app depends on by path, each standalone with its own readme:

- `transcriber/`: audio capture, playback, and transcription: the `AudioRecorder`, `AudioPlayer` and `TranscriptionEngine` contracts, their platform implementations, and the Swift behind them.
- `reflections/`: the `ReflectionEngine` contract, the `ReflectionPeriod` vocabulary, and the Foundation Models implementation.
- `liquid/`: vendored native iOS 26 Liquid Glass chrome.

Stack: Flutter, `flutter_bloc` for state, `go_router` for navigation, `shared_preferences` + `encrypt` for storage, `flutter_svg` for the export format marks, and the `packages/` plugins above. The launch splash is native (`ios/Runner/WaveSplash.swift`, handed off from `lib/core/app/splash_handoff.dart`), not a Flutter asset. No `get_it`, no `injectable`, no build_runner. The only codegen is `flutter gen-l10n`.

## Dependency injection

DI is a **typed composition root**, `Deps` in `core/app/deps.dart`. No service locator, no code generation, no `BuildContext` needed to reach a dependency.

- Access anywhere: `Deps.i.localService`, `Deps.i.transcriptionService`, `Deps.i.router`.
- Add a dependency: give it a typed field on `Deps`, construct it in `Deps.init()`. That is the whole ceremony.
- `Deps.init()` runs once, before `runApp`, and holds only what the first frame cannot be built without. Anything that must not block launch goes in `unawaited`.
- Launch-time repair (reconciling orphaned audio, healing dangling records, the reflection catch-up) belongs in `Deps.launchMaintenance()`, not in `init`: every pass decrypts the whole journal, so it must not run on the frames the user is watching. The app root calls it once the first frames are on screen, and again on foreground when a pass was cut short.
- Do not reintroduce `get_it`/`injectable`, and do not use context-based DI (`provider`, `RepositoryProvider`, Riverpod `ref`) for wiring. `BlocProvider` is fine for scoping cubits to the widget tree.

## UI rules

- **The app draws its own controls.** `package:flutter/material.dart` and `package:flutter/cupertino.dart` are banned in `lib/` and the package libs under `packages/`, enforced by `test/view/no_framework_imports_test.dart`. Build on `package:flutter/widgets.dart` plus `view/widgets/`.
- Styling comes from `AppTheme` through `context.theme`. No literal colors or magic numbers in widgets; add a token to `core/theming/` instead, and derive new component groups from the base palette (`AppTheme.fromBase`).
- Icons come from `AppIcons`, a vendored SF Symbols subset font (`assets/icons/sficons.ttf`). Regenerate the subset to add a glyph. Do not add icons from another set, and do not turn `uses-material-design` back on.
- Native iOS 26 Liquid Glass chrome comes from `packages/liquid` (vendored, renders locally). Every use is gated on `PlatformCaps.nativeGlass` with a drawn fallback such as `AppIconButton` or `showAppMenu`, because the plugin renders nothing below iOS 26.

## The native layer (iOS)

Capture, speech, playback, and reflection Swift lives in the plugin packages and registers through `GeneratedPluginRegistrant`. Each plugin is a `MethodChannel` for control plus `EventChannel`s for streams:

- `AudioCapture.swift` and `AudioCompose.swift` (`packages/transcriber`): `transcriber/audio` (capture and `concatenate`), `/audio/status`, `/audio/level`
- `SpeechEngine.swift` (`packages/transcriber`): `transcriber/speech`, `/speech/events`, `/speech/model`
- `AudioPlayer.swift` (`packages/transcriber`): `transcriber/player`, `/player/state`
- `ReflectionEngine.swift` (`packages/reflections`): `reflections/reflect`

App-only Swift stays under `ios/Runner/`, registered in `AppDelegate.didInitializeImplicitFlutterEngine`: notifications, the storage key, share export, the splash hand-off, intent actions, the StoreKit support store (`opentranscribe/support` plus its event channel), and the thermal monitor (`opentranscribe/thermal` plus its event channel, wrapped by `core/utils/thermal.dart`). The Live Activity is `ios/Runner/RecordingLiveActivity.swift` driving the widget extension in `ios/RecorderActivity/`, over the attributes shared in `ios/Shared/`; it is fed capture status through `TranscriberPlugin.recordingStatusObserver`, set in `AppDelegate`.

Channels are only ever touched from a wrapper (`PlatformAudioRecorder`, `PlatformAudioComposer`, `PlatformAudioPlayer`, `AppleSpeechEngine`, and the app-level `SupportStore`), never from `view/`. Those wrappers take their channels as constructor arguments so tests can inject fakes.

## Commands

```
flutter pub get                 # install deps
flutter run -d ios              # run on an iOS simulator/device
./tool/checks.sh                # analyze, format-check, and test the app and every package
flutter gen-l10n                # regenerate localizations after editing .arb
```

Bare `flutter test` / `flutter analyze` only cover the app; the plugins under `packages/` carry their own analysis context and test suite, so `tool/checks.sh` is the one command that matches what CI runs.

The journal's encryption key is a per-device random key generated on first launch and held in the Keychain (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`); it never leaves the device. `STORAGE_KEY` remains a build-time secret, never committed, needed only to read and migrate records written before the Keychain key existed. Debug builds fall back to a committed development key; a release build throws at `Deps.init()` unless a real one is supplied:

```
flutter run --dart-define=STORAGE_KEY=<your-32-char-key>
```

## Testing

- Unit tests only, under `test/` mirroring `lib/`; each package under `packages/` mirrors its own `lib/` in its own `test/`. The one native suite is `packages/transcriber/ios/transcriber/Core`, a Flutter-free Swift package holding the transcript stitching rules so `swift test` can reach them. **No widget tests.** When UI behavior needs coverage, pull the logic out into a pure function next to the widget (`rollingSlots`, `resamplePeaks`) and test that. This is why `test/view/` exists and why nothing in it pumps a widget tree.
- Fakes live in `test/support/`. Inject them through constructors; no test may reach a real platform channel or real storage.
- Test names read as sentences about behavior, not about method names. Tests carry no comments; the name is the explanation, so put the reasoning there.

## Conventions

- Follow `analysis_options.yaml`: single quotes, trailing commas, `const` wherever possible, package imports only (no relative `lib` imports), `prefer_final_locals`, 100-column formatting. Keep `flutter analyze` clean.
- Localization: add the key to `lib/l10n/app_en.arb` (the template) and every other `app_*.arb`, run `flutter gen-l10n`, then read it with `AppLocalizations.of(context)!.<key>`. No hardcoded user-facing strings outside debug-only surfaces like the gallery. Generated files under `lib/l10n/generated/` are committed but never hand-edited.
- Navigation: add the path and name to `Routes`, wire the `GoRoute` in `app_router.dart`, and navigate with `context.goNamed(Routes.<x>Name)`. Never hardcode a path at a call site.
- State: one cubit per concern under `core/state/`; screens consume them via `BlocProvider`/`BlocBuilder`. Business logic belongs in a cubit or a service, not in a widget.
- Widgets: reusable ones in `view/widgets/`, screen-specific ones in that domain's `components/`. Prefer small, composable, `const` widgets over deep build methods.
- Writing (comments, docs, commit messages): plain and terse. No em-dashes. **Comments only when needed: the default is no comment.** One earns its place only by stating a why or a constraint the code cannot express; never narrate what code does, its history, or the change that produced it. Tests carry no comments; the test name is the explanation. Doc comments on a contract state the guarantees a caller may rely on, including what an implementation must not do.

## Commit style

Single-line conventional commits, nothing else:

```
type(scope): what changed
```

- Types: `feat`, `fix`, `refactor`, `chore`, `docs`, `test`, `perf`, `ci`.
- Scopes: `core`, `view`, `routes`, `storage`, `l10n`, `deps`, `transcribe`, `audio`, `theming`, `ios`, `liquid`, `transcriber`, `reflections` (extend as the code grows).
- No body, no title/body split. Messages describe the change, never the process or finding counts.
- **No `Co-Authored-By` trailer.** This overrides the harness default.
- Do not commit unless asked.

## Never

- Add a network call, analytics, crash reporting, or any SDK that transmits off-device.
- Add a `features/` folder or otherwise blur the `core/` vs `view/` split.
- Import `material.dart` or `cupertino.dart` in `lib/`, or reach for a Material/Cupertino widget instead of the design system.
- Reach for `get_it`, `injectable`, code generation for DI, or context-based DI.
- Couple UI, storage, or services to a specific transcription engine.
- Call a platform channel from `view/`, or let audio bytes cross the engine boundary.
- Write a Flutter widget test.
