# transcriber

Audio capture, playback, and on-device transcription for Flutter on iOS. The app-facing surface is three contracts: `AudioRecorder`, `AudioPlayer`, and `TranscriptionEngine`, with streaming, batch cancellation, downloadable-model behavior, and side-effect-free per-language readiness as separate interfaces an engine may also implement (`StreamingTranscriptionEngine`, `CancellableBatchEngine`, `ManagedModelEngine`, `LanguageReadinessEngine`). `AppleSpeechEngine` is the shipped `SpeechAnalyzer` implementation (iOS 26); `AppleDictationEngine` is the classic `SFSpeechRecognizer` one, the engine behind iOS dictation.

Guarantees a caller may rely on:

- `TranscriptionEngine.onDeviceOnly` states whether an engine keeps audio on the device. Both `AppleSpeechEngine` and `AppleDictationEngine` force on-device recognition and answer true, and nothing in this package opens a network connection.
- Both engines share one live-event transport over `transcriber/speech/events`, and live session tokens are unique across them; every engine-answering channel call names its engine, so the native side routes explicitly.
- Audio buffers never cross the platform channel. Capture and recognition share one native session; only paths, durations, levels, statuses, and text reach Dart.
- Recording and playback share the audio session and never overlap. Starting a capture stops live playback with a terminal event, and `AudioPlayer.play` throws `busy_recording` while a capture runs.
- Recordings land in the app's Application Support under iOS data protection (`completeUnlessOpen`), excluded from backup by default; `AudioRecorder.setBackupExcluded` flips that for the whole directory.

The channels, one Swift class per channel family, all internal to the package (the two speech engines are two Dart wrappers over the one speech class, routed by the engine argument):

| Dart wrapper | Method channel | Event channels |
| --- | --- | --- |
| `PlatformAudioRecorder` | `transcriber/audio` | `transcriber/audio/status`, `transcriber/audio/level` |
| `AppleSpeechEngine`, `AppleDictationEngine` | `transcriber/speech` | `transcriber/speech/events`, `transcriber/speech/model` |
| `PlatformAudioPlayer` | `transcriber/player` | `transcriber/player/state` |

Each wrapper takes its channels as constructor arguments so tests can inject fakes; the defaults bind the names above. Registration is one class, `TranscriberPlugin`, reached through the generated registrant.

A host app provides `NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription` in its Info.plist, `UIBackgroundModes` `audio` if a recording should survive backgrounding, and iOS 17 or newer.

`TranscriberPlugin.recordingStatusObserver` is an optional native hook: capture status strings (`recording`, `paused`, `interrupted`, `stopped`) delivered after Dart's own status sink, for surfaces the package must not know about. opentranscribe drives its Live Activity with it.

`package:transcriber/testing.dart` exports `FakeStreamingEngine`, `FakeBatchEngine`, `FakeManagedEngine`, `FakeDictationEngine`, and `FakeOffDeviceEngine` for tests that need an engine without a device.
