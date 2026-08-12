# reflections

On-device reflection generation for Flutter on iOS. The app-facing surface is one contract, `ReflectionEngine`: an availability probe, then `reflect` over a period's entries with a style, answering plain text. `FoundationModelsEngine` is the shipped implementation, Apple's Foundation Models through `SystemLanguageModel.default`.

Guarantees a caller may rely on:

- `ReflectionEngine.onDeviceOnly` states whether an engine keeps journal text on the device. `FoundationModelsEngine` answers true, never uses Private Cloud Compute or any server, and refuses to run when the on-device model is unavailable.
- Silence is a result. An empty response or a guardrail refusal comes back as empty text, never as an error, so a quiet period reads as quiet.
- Transient system conditions (throttled, model assets evicted, a concurrent request) surface as `ReflectionUnavailable` so the caller retries later; they never masquerade as silence.
- `ReflectionPeriod` wire strings (`daily`, `weekly`, `monthly`) are a stable contract, used as storage key segments, settings fragments, and prompt tags. A value is never repurposed.

One method channel, `reflections/reflect`, injectable through the engine's constructor for tests; the plugin class is `ReflectionEnginePlugin`, reached through the generated registrant.

A host app needs iOS 17 or newer and nothing else. The engine reports `unsupported` below iOS 26, `device_not_eligible` on hardware without Apple Intelligence, and `not_enabled` when Apple Intelligence is off; availability, not the host, decides whether the feature shows.

`package:reflections/testing.dart` exports `FakeReflectionEngine` for tests that need an engine without a device.
