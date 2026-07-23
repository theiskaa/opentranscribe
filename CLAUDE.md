# opentranscribe

A private, offline voice journal. You speak your mind, it writes it down, and it stays on your device. Built with Flutter, iOS-first.

## The one rule

**Nothing leaves the phone.** No network calls, no accounts, no analytics, no third-party SDK that phones home. The app must work fully in airplane mode. This is not a feature, it is the architecture, and it constrains every decision below. If a change would open a socket or ship data off-device, it does not belong here.

Corollaries that shape the code:
- Transcription and reflection run on-device. The transcription engine is meant to be **swappable** (Apple Speech first, whisper.cpp later) behind one contract, so nothing in `view/` or the data layer should depend on a specific engine.
- Raw audio for each entry is kept on-device, so entries can be re-transcribed later by a better engine. Audio capture is app-owned, not engine-owned.

## Architecture

Two layers only. There is no `features/` layer, and we do not want one.

- `lib/core/` — everything non-UI.
  - `core/app/` — composition root (`deps.dart`), on-device storage (`local_service.dart`), locale source-of-truth (`app_language.dart`).
  - `core/routes/` — `app_router.dart` (the `GoRouter`) and `routes.dart` (path/name constants).
  - As the app grows, add sibling folders here per concern: `core/models/`, `core/services/`, `core/state/` (blocs/cubits), `core/theming/`, `core/utils/`.
- `lib/view/` — everything UI.
  - `view/app.dart` — the root `App` widget (`MaterialApp.router`).
  - `view/layouts/<domain>/screens/<name>_screen.dart` — full screens; `<name>Screen` class names.
  - `view/layouts/<domain>/components/` — widgets private to that domain.
  - `view/widgets/` — the shared, reusable widget set (design system).
- `lib/main.dart` and `lib/bootstrap.dart` live at the root. `bootstrap` calls `Deps.init()` then `runApp`.
- `lib/l10n/` — `.arb` files and generated localizations.

Stack: Flutter, `flutter_bloc` for state, `go_router` for navigation, `shared_preferences` + `encrypt` for storage. No `get_it`, no `injectable`, no build_runner. The only codegen is `flutter gen-l10n`.

## Dependency injection

DI is a **typed composition root**, `Deps` in `core/app/deps.dart`. No service locator, no `get_it`, no code generation, and no `BuildContext` needed to reach a dependency.

- Access anywhere: `Deps.i.localService`, `Deps.i.router`.
- Add a dependency: give it a typed field on `Deps`, construct it in `Deps.init()`. That is the whole ceremony.
- Do not reintroduce `get_it`/`injectable`, and do not use context-based DI (`provider`, `RepositoryProvider`, Riverpod `ref`) for wiring dependencies. `BlocProvider` is fine for scoping cubits to the widget tree.

## Commands

```
flutter pub get                 # install deps
flutter run -d ios              # run on an iOS simulator/device
flutter analyze                 # static analysis (must be clean before commit)
flutter test                    # run tests
flutter gen-l10n                # regenerate localizations after editing .arb
```

The storage encryption key is a build-time secret, never committed:

```
flutter run --dart-define=STORAGE_KEY=<your-32-char-key>
```

## Conventions

- Follow `analysis_options.yaml`. Key points: single quotes, trailing commas, `const` wherever possible, package imports only (no relative `lib` imports), 100-column formatting. Run `flutter analyze` and keep it clean.
- Localization: add a key to `lib/l10n/app_en.arb` (the template) and every other `app_*.arb`, run `flutter gen-l10n`, then read it with `AppLocalizations.of(context)!.<key>`. No hardcoded user-facing strings.
- Navigation: add the path/name to `Routes`, wire the `GoRoute` in `app_router.dart`, and navigate with `context.goNamed(Routes.<x>Name)`. Do not hardcode path strings at call sites.
- State: one cubit/bloc per concern under `core/state/`; screens consume them via `BlocProvider`/`BlocBuilder`. Keep business logic out of widgets.
- Widgets: reusable widgets go in `view/widgets/`; screen-specific ones in that domain's `components/`. Prefer small, composable, `const` widgets over deep build methods.
- Writing (comments, docs, commit messages): plain and terse. No em-dashes. Comment the why, not the what.

## Commit style

Single-line conventional commits, nothing else:

```
type(scope): what changed
```

- Types: `feat`, `fix`, `refactor`, `chore`, `docs`, `test`, `perf`, `ci`.
- Scopes: `core`, `view`, `routes`, `storage`, `l10n`, `deps`, `transcribe` (extend as the code grows).
- No body, no title/body split. Messages describe the change, never the process or finding counts.
- **No `Co-Authored-By` trailer.** This overrides the harness default.

## Never

- Add a network call, analytics, crash reporting, or any SDK that transmits off-device.
- Add a `features/` folder or otherwise blur the `core/` vs `view/` split.
- Reach for `get_it`, `injectable`, code generation for DI, or context-based DI.
- Couple UI or storage to a specific transcription engine.
