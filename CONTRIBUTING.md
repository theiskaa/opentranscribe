# Contributing to opentranscribe

Thanks for wanting to help. This is the practical guide: how to build it, how the code is arranged, the conventions it holds to, and what will get a pull request sent back.

## The one rule

**Nothing leaves the phone.** No network calls, no accounts, no analytics, no third-party SDK that phones home. The app must work fully in airplane mode. This is not a feature, it is the architecture, and it is not negotiable in a pull request. Anything that opens a socket or ships data off-device does not belong here, whatever it is attached to.

Transcription and reflection each run behind a contract, `TranscriptionEngine` and `ReflectionEngine`, with a hard `onDeviceOnly` gate: the app refuses at construction any engine that answers false, and there is no cloud fallback for either. Only text ever crosses those boundaries, never audio.

## Getting started

Flutter 3.44 or newer, Xcode, and an iOS 17+ target. Prefer a real device: the microphone, the speech models, the Live Activity, and reflections only partly work in the simulator, if at all.

```sh
flutter pub get
flutter run -d ios
```

The journal's encryption key is a per-device random key generated on first launch and held in the Keychain (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`); it never leaves the device. `STORAGE_KEY` remains a build-time secret, never committed, needed only to read and migrate records written before the Keychain key existed. Debug builds fall back to a development key; a release build refuses to start without a real one:

```sh
flutter run --release --dart-define=STORAGE_KEY=<your-32-char-key>
```

## Before you open a pull request

All four must pass. Review holds this line.

```sh
flutter analyze      # must be clean
flutter test         # must be green
dart format .        # 100 columns
flutter gen-l10n     # after editing lib/l10n/app_en.arb
```

## Project layout

Two layers, and there is no third. There is no `features/` folder and we do not want one.

`lib/core/` is everything non-UI:

- `app/` the composition root (`deps.dart`), encrypted storage (`local_service.dart`), locale source of truth, onboarding flags.
- `audio/` the `AudioRecorder` and `AudioPlayer` contracts with their platform-channel implementations and value types.
- `export/` the `JournalExporter` contract, the shipped format exporters, and the native archive: store-only zip codec, manifest, sealed container crypto, and the share-sheet channel wrapper.
- `models/` plain data (`entry.dart`, `engine_descriptor.dart`, `exporter_descriptor.dart`).
- `routes/` the `GoRouter`, the path and name constants, page transitions.
- `services/` `transcription_service.dart` (the one owner of the entry lifecycle), `entry_store.dart`, the settings holders.
- `state/` one cubit per concern.
- `theming/` `AppTheme` and its tokens, `AppIcons`, motion, shapes, the type scale.
- `transcribe/` the transcription engine contract and its implementations.
- `reflect/` the reflection engine contract and its implementations.
- `notify/` the local notification scheduler and the weekly reflection nudge.
- `utils/` haptics, platform capability probes, small helpers.

`lib/view/` is everything UI:

- `app.dart` the root `App` widget, a `WidgetsApp.router` with no Material or Cupertino shell, providing the cubits above the router.
- `layouts/<domain>/screens/` full screens and `layouts/<domain>/components/` the widgets private to that domain (`entry`, `home`, `recorder`, `reflections`, `settings`, `onboarding`, `splash`, `gallery`).
- `widgets/` the shared, reusable design system.

The stack is Flutter with `flutter_bloc` for state, `go_router` for navigation, `shared_preferences` plus `encrypt` for storage, `lottie` for the splash, and the vendored `packages/liquid` plugin for native iOS chrome. No `get_it`, no `injectable`, no `build_runner`. The only code generation is `flutter gen-l10n`.

## How it works

**Dependency injection** is a typed composition root, `Deps` in `core/app/deps.dart`. No service locator, no code generation, no `BuildContext` needed to reach a dependency. Access anything with `Deps.i.<field>`. To add a dependency, give it a typed field on `Deps` and construct it in `Deps.init()`, which runs once before `runApp` and is where launch-time repair belongs.

**Transcription** sits behind `TranscriptionEngine`. Apple's Speech framework is the first implementation (`SpeechAnalyzer` on iOS 26, `SFSpeechRecognizer` below it), with whisper.cpp meant to land as a second without the rest of the app noticing. Streaming and downloadable-model behavior are separate interfaces an engine may also implement (`StreamingTranscriptionEngine`, `ManagedModelEngine`), not flags. Live text is painted while you speak and then discarded; the saved transcript is a batch pass over the finished file. Speech models are per-language and on-device, bounded by the cap iOS 26 places on how many one app may hold. `transcription_service.dart` owns the whole entry lifecycle, keeping the recorder, engine, and store private inside it.

**Reflection** sits behind `ReflectionEngine`, held to the same on-device gate. It runs on Apple's Foundation Models, writes one note per closed week, and is simply absent on hardware without Apple Intelligence. An optional weekly notification, local and on-device like everything else, nudges you when a new one is ready.

**Audio capture** is app-owned, not engine-owned. Buffers stay native and only paths, durations, levels, and text cross the platform channel. Raw audio is kept by default so any entry can be re-transcribed later, in another language or by a better engine. Keeping is a preference: with keep-audio off, a recording is deleted after its first successful transcription and the entry becomes transcript-only (`Entry.audioPath` is nullable). Bulk reclaim of kept history is only ever the Cache screen's explicit, confirmed action.

**The native layer** is Swift under `ios/Runner/`, registered in `AppDelegate.didInitializeImplicitFlutterEngine`. Each plugin is a `MethodChannel` for control plus `EventChannel`s for its streams: audio capture (`opentranscribe/audio`, `/audio/status`, `/audio/level`), speech (`opentranscribe/speech`, `/speech/events`, `/speech/model`), playback (`opentranscribe/player`, `/player/state`), notifications (`opentranscribe/notify`), and reflection. The in-progress recording drives a Live Activity (`RecordingLiveActivity.swift`, the widget extension in `ios/RecorderActivity/`, attributes in `ios/Shared/`). Channels are touched only from a `core/` wrapper (`PlatformAudioRecorder`, `PlatformAudioPlayer`, `AppleSpeechEngine`), never from `view/`, and each wrapper takes its channels as constructor arguments so tests can inject fakes.

**At rest**, recordings are AAC in the app's own directory, written with iOS data protection and excluded from iCloud and device backups by default. Entries are encrypted JSON in the local key-value store, AES-256-GCM with a fresh nonce per record. The encryption key is a random 32-byte value generated on first launch and held in the Keychain, one per device, never a value in the repo. See [SECURITY.md](SECURITY.md) for the trust model.

**UI** is drawn by the app itself. The root is a `WidgetsApp.router` with no Material or Cupertino shell. Styling comes from `AppTheme` through `context.theme`; icons come from `AppIcons`, a vendored SF Symbols subset, regenerated to add a glyph. Native iOS 26 Liquid Glass chrome comes from `packages/liquid`, gated on `PlatformCaps.nativeGlass` with a drawn fallback, because the plugin renders nothing below iOS 26.

## Conventions

- `analysis_options.yaml` is the law: single quotes, trailing commas, `const` wherever possible, package imports only (no relative `lib` imports), `prefer_final_locals`, 100-column formatting.
- One cubit per concern under `core/state/`, consumed through `BlocProvider` and `BlocBuilder`. Business logic belongs in a cubit or a service, never in a widget.
- Reusable widgets go in `view/widgets/`, screen-specific ones in that domain's `components/`. Prefer small, composable, `const` widgets over deep build methods, and extract a private widget rather than building one from a method. New shared widgets belong in the gallery (`Routes.gallery`, debug builds only) so they can be eyeballed on device in every state.
- Navigation: add the path and name to `Routes`, wire the `GoRoute` in `app_router.dart`, navigate with `context.goNamed(Routes.<x>Name)`. Never hardcode a path at a call site.
- Localization: add the key to `lib/l10n/app_en.arb` and every other `app_*.arb`, run `flutter gen-l10n`, then read it with `AppLocalizations.of(context)!.<key>`. Generated files under `lib/l10n/generated/` are committed but never hand-edited.
- Writing, in code and prose, is plain and terse. Comments earn their place only by stating a why or a constraint the code cannot express; the default is no comment. No em-dashes.

## Testing

Unit tests only, under `test/` mirroring `lib/`. **No widget tests.** When UI behavior needs coverage, pull the logic into a pure function next to the widget and test that; this is why `test/view/` exists and why nothing in it pumps a widget tree. Fakes live in `test/support/` and are injected through constructors, so no test reaches a real platform channel or real storage. Test names read as sentences about behavior, and tests carry no comments because the name is the explanation.

## Rules that will fail review

- No `material.dart` or `cupertino.dart` anywhere in `lib/`. Build on `package:flutter/widgets.dart` and the design system in `view/widgets/`. A test enforces this.
- No Flutter widget tests.
- No `get_it`, `injectable`, DI code generation, or context-based wiring. Add a typed field to `Deps`.
- No network call, analytics, crash reporting, or any SDK that transmits off-device.
- Do not couple UI, storage, or services to a concrete engine, and do not let audio bytes cross the engine boundary.
- Do not call a platform channel from `view/`.
- No hardcoded user-facing strings, and no literal colors or magic numbers in widgets. Add a token to `core/theming/` and style through `context.theme`.
- Do not add a `features/` folder, do not add icons from another set, and do not turn `uses-material-design` back on.

## Adding common things

- **A dependency:** a typed field on `Deps`, constructed in `Deps.init()`.
- **A route:** the path and name on `Routes`, a `GoRoute` in `app_router.dart`, reached with `context.goNamed`.
- **A user-facing string:** the key in `app_en.arb` and every other `app_*.arb`, then `flutter gen-l10n`, read with `AppLocalizations`.
- **A transcription or reflection engine:** implement the contract, answer `onDeviceOnly` true, wire it in only from `Deps`. Surfaces that must show an engine name read the `EngineDescriptor` list `Deps` builds, so nothing else names a concrete engine.
- **An export format** (Notion, Apple Notes, ...): implement `JournalExporter` in `core/export/` as pure Dart, models in and files out, with no I/O, no clock reads, and no l10n (the localized scaffold strings arrive in `ExportContext`). Register it in the exporter map in `Deps.init()` and add its `ExporterDescriptor` there, the one place allowed to name an exporter; the entry sheet, the Backup screen, and both export paths pick it up from the descriptor list with no further plumbing.
- **A shared widget:** put it in `view/widgets/` and add it to the debug-only gallery.

## Commits

Single-line conventional commits, nothing else:

```
type(scope): what changed
```

- Types: `feat`, `fix`, `refactor`, `chore`, `docs`, `test`, `perf`, `ci`.
- Scopes: `core`, `view`, `routes`, `storage`, `l10n`, `deps`, `transcribe`, `audio`, `theming`, `ios`, `liquid`, extended as the code grows.
- No body, no title and body split. Describe the change, not the process.

## Pull requests

Keep them small and focused, one concern each, and green before you open them. Describe what changed and why, and link the issue it closes.

## Conduct and security

Participation is governed by our [Code of Conduct](CODE_OF_CONDUCT.md). Do not open a public issue for a security problem; use the private channel in [SECURITY.md](SECURITY.md).
