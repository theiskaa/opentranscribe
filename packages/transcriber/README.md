# transcriber

Audio capture, playback, and on-device transcription for Flutter on iOS. The app-facing surface is four contracts: `AudioRecorder`, `AudioComposer`, `AudioPlayer`, and `TranscriptionEngine`, with streaming, batch cancellation, downloadable-model behavior, and side-effect-free per-language readiness as separate interfaces an engine may also implement (`StreamingTranscriptionEngine`, `CancellableBatchEngine`, `ManagedModelEngine`, `LanguageReadinessEngine`). `AppleSpeechEngine` is the shipped `SpeechAnalyzer` implementation (iOS 26); `AppleDictationEngine` is the classic `SFSpeechRecognizer` one, the engine behind iOS dictation.

Guarantees a caller may rely on:

- `TranscriptionEngine.onDeviceOnly` states whether an engine keeps audio on the device. Both `AppleSpeechEngine` and `AppleDictationEngine` force on-device recognition and answer true, and nothing in this package opens a network connection.
- Both engines share one live-event transport over `transcriber/speech/events`, and live session tokens are unique across them; every engine-answering channel call names its engine, so the native side routes explicitly.
- Audio buffers never cross the platform channel. Capture and recognition share one native session; only paths, durations, levels, statuses, and text reach Dart.
- Recording and playback share the audio session and never overlap. Starting a capture stops live playback with a terminal event, and `AudioPlayer.play` throws `busy_recording` while a capture runs.
- Recordings land in the app's Application Support under iOS data protection (`completeUnlessOpen`), excluded from backup by default; `AudioRecorder.setBackupExcluded` flips that for the whole directory.
- `AudioComposer.concatenate` (riding the recorder's channel, with no channel of its own) joins kept recordings into one new file: each input is decoded to PCM and re-encoded once at the first input's sample rate and channel count with the capture bitrate tier, so takes from different routes merge cleanly. The output is staged under `Application Support/compose` and moved into the recordings directory only when complete; inputs are never touched, and a failure leaves nothing partial in the recordings directory.

The channels, one Swift class per channel family, all internal to the package (the two speech engines are two Dart wrappers over the one speech class, routed by the engine argument):

| Dart wrapper | Method channel | Event channels |
| --- | --- | --- |
| `PlatformAudioRecorder` | `transcriber/audio` | `transcriber/audio/status`, `transcriber/audio/level` |
| `PlatformAudioComposer` | `transcriber/audio` (`concatenate`) | |
| `AppleSpeechEngine`, `AppleDictationEngine` | `transcriber/speech` | `transcriber/speech/events`, `transcriber/speech/model` |
| `PlatformAudioPlayer` | `transcriber/player` | `transcriber/player/state` |

Each wrapper takes its channels as constructor arguments so tests can inject fakes; the defaults bind the names above. Registration is one class, `TranscriberPlugin`, reached through the generated registrant.

A host app provides `NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription` in its Info.plist, `UIBackgroundModes` `audio` if a recording should survive backgrounding, and iOS 17 or newer.

`TranscriberPlugin.recordingStatusObserver` is an optional native hook: capture status strings (`recording`, `paused`, `interrupted`, `stopped`) delivered after Dart's own status sink, for surfaces the package must not know about. opentranscribe drives its Live Activity with it.

`package:transcriber/testing.dart` exports `FakeStreamingEngine`, `FakeBatchEngine`, `FakeManagedEngine`, `FakeDictationEngine`, and `FakeOffDeviceEngine` for tests that need an engine without a device.

The classic recognizer hands out only its current utterance, and resets that
hypothesis after a pause of about two seconds. `UtteranceStitcher` rebuilds the
whole take from those pieces, and `feedHolds` paces the file feeder that drives
it. Both live in `ios/transcriber/Core`, a Swift package with no Flutter
dependency, so `swift test` can reach the rules;
`tool/checks.sh` in the host app runs them. Keep it free of iOS-only API: those
tests build for the host.
