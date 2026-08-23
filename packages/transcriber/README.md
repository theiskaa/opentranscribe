# transcriber

Audio capture, playback, and on-device transcription for Flutter on iOS. The app-facing surface is three contracts: `AudioRecorder`, `AudioPlayer`, and `TranscriptionEngine`, with streaming, batch cancellation, and downloadable-model behavior as separate interfaces an engine may also implement (`StreamingTranscriptionEngine`, `CancellableBatchEngine`, `ManagedModelEngine`). `AppleSpeechEngine` is the shipped implementation: `SpeechAnalyzer` on iOS 26 where the device reports analyzer locales (probed once per launch; 8-core Neural Engine devices never do), `SFSpeechRecognizer` otherwise.

Guarantees a caller may rely on:

- `TranscriptionEngine.onDeviceOnly` states whether an engine keeps audio on the device. `AppleSpeechEngine` forces on-device recognition and answers true, and nothing in this package opens a network connection.
- Audio buffers never cross the platform channel. Capture and recognition share one native session; only paths, durations, levels, statuses, and text reach Dart.
- Recording and playback share the audio session and never overlap. Starting a capture stops live playback with a terminal event, and `AudioPlayer.play` throws `busy_recording` while a capture runs.
- Recordings land in the app's Application Support under iOS data protection (`completeUnlessOpen`), excluded from backup by default; `AudioRecorder.setBackupExcluded` flips that for the whole directory.

The channels, one Swift class per Dart wrapper, all internal to the package:

| Dart wrapper | Method channel | Event channels |
| --- | --- | --- |
| `PlatformAudioRecorder` | `transcriber/audio` | `transcriber/audio/status`, `transcriber/audio/level` |
| `AppleSpeechEngine` | `transcriber/speech` | `transcriber/speech/events`, `transcriber/speech/model` |
| `PlatformAudioPlayer` | `transcriber/player` | `transcriber/player/state` |

Each wrapper takes its channels as constructor arguments so tests can inject fakes; the defaults bind the names above. Registration is one class, `TranscriberPlugin`, reached through the generated registrant.

A host app provides `NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription` in its Info.plist, `UIBackgroundModes` `audio` if a recording should survive backgrounding, and iOS 17 or newer.

`TranscriberPlugin.recordingStatusObserver` is an optional native hook: capture status strings (`recording`, `paused`, `interrupted`, `stopped`) delivered after Dart's own status sink, for surfaces the package must not know about. opentranscribe drives its Live Activity with it.

`package:transcriber/testing.dart` exports `FakeStreamingEngine`, `FakeBatchEngine`, and `FakeManagedEngine` for tests that need an engine without a device.
