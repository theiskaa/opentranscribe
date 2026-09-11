# transcriber

Audio capture, playback, and on-device transcription for Flutter on iOS. The app-facing surface is four contracts: `AudioRecorder`, `AudioComposer`, `AudioPlayer`, and `TranscriptionEngine`, with streaming, batch cancellation, downloadable-model behavior, and side-effect-free per-language readiness as separate interfaces an engine may also implement (`StreamingTranscriptionEngine`, `CancellableBatchEngine`, `ManagedModelEngine`, `LanguageReadinessEngine`). `AppleSpeechEngine` is the shipped `SpeechAnalyzer` implementation (iOS 26); `AppleDictationEngine` is the classic `SFSpeechRecognizer` one, the engine behind iOS dictation; `WhisperEngine` is whisper.cpp, batch-only, one downloaded model of a catalog serving every language it knows (`ModelChoiceEngine`, `PacedBatchEngine`, `ReleasableEngine`, `ProgressBatchEngine` for the run's percent, and `AcceleratedModelEngine` for the Core ML encoder it can fetch beside a model and run on the Neural Engine).

Guarantees a caller may rely on:

- `TranscriptionEngine.onDeviceOnly` states whether an engine keeps audio on the device. All three engines force on-device recognition and answer true. The one connection this package opens is `PinnedHostFetcher` in `lib/src/whisper/model_fetcher.dart`: it downloads a catalog file the caller asked for (a model, or its zipped Core ML encoder) from one pinned host (redirects only onto that host's CDN), resumes a `.part` with a Range request, retries a transfer that broke after bytes arrived, verifies the sha256 before the file counts as installed, and sends nothing.
- Both Apple engines share one live-event transport over `transcriber/speech/events`, and live session tokens are unique across them; every engine-answering channel call names its engine, so the native side routes explicitly.
- Audio buffers never cross the platform channel. Capture and recognition share one native session; only paths, durations, levels, statuses, and text reach Dart.
- Recording and playback share the audio session and never overlap. Starting a capture stops live playback with a terminal event, and `AudioPlayer.play` throws `busy_recording` while a capture runs.
- Recordings land in the app's Application Support under iOS data protection (`completeUnlessOpen`), excluded from backup by default; `AudioRecorder.setBackupExcluded` flips that for the whole directory.
- `AudioComposer.concatenate` (riding the recorder's channel, with no channel of its own) joins kept recordings into one new file: each input is decoded to PCM and re-encoded once at the first input's sample rate and channel count with the capture bitrate tier, so takes from different routes merge cleanly. The output is staged under `Application Support/compose` and moved into the recordings directory only when complete; inputs are never touched, and a failure leaves nothing partial in the recordings directory.

The channels, one Swift class per channel family, all internal to the package (the two speech engines are two Dart wrappers over the one speech class, routed by the engine argument):

| Dart wrapper | Method channel | Event channels |
| --- | --- | --- |
| `PlatformAudioRecorder` | `transcriber/audio` | `transcriber/audio/status`, `transcriber/audio/level` |
| `PlatformAudioComposer` | `transcriber/audio` (`concatenate`) | |
| `PlatformPcmDecoder` | `transcriber/audio` (`decodePcm`) | |
| `PlatformModelStorage` | `transcriber/audio` (`modelsDirectory`, `physicalMemory`) | |
| `AppleSpeechEngine`, `AppleDictationEngine` | `transcriber/speech` | `transcriber/speech/events`, `transcriber/speech/model` |
| `PlatformAudioPlayer` | `transcriber/player` | `transcriber/player/state` |

Each wrapper takes its channels as constructor arguments so tests can inject fakes; the defaults bind the names above. Registration is one class, `TranscriberPlugin`, reached through the generated registrant.

A host app provides `NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription` in its Info.plist, `UIBackgroundModes` `audio` if a recording should survive backgrounding, and iOS 17 or newer.

`TranscriberPlugin.recordingStatusObserver` is an optional native hook: capture status strings (`recording`, `paused`, `interrupted`, `stopped`) delivered after Dart's own status sink, for surfaces the package must not know about. opentranscribe drives its Live Activity with it.

`package:transcriber/testing.dart` exports `FakeStreamingEngine`, `FakeBatchEngine`, `FakeManagedEngine`, `FakeDictationEngine`, `FakeOffDeviceEngine`, `FakeModelChoiceEngine`, `FakeAudioComposer`, `FakePcmDecoder`, `FakeModelFetcher`, and `FakeWhisperRuntime` for tests that need any of the contracts without a device.

`PcmDecoder` (`PlatformPcmDecoder`, riding the recorder's channel as `decodePcm`) decodes a slice of a kept recording into raw 16 kHz mono 32-bit float samples under `Application Support/scratch`, for an engine that reads samples from a file. The slice is bounded in the input's own time, a slice holding no frames fails as `decode_empty` rather than answering silence, and the caller deletes the output. `length` answers the input's duration from its header. `WhisperEngine` runs audio longer than `chunkLength` (ten minutes) as one slice at a time, re-hearing a segment the boundary cut, so a run of any length holds ten minutes of samples at most. The frame math is `pcmSlice` in `ios/transcriber/Core`.

`WhisperEngine` (`lib/src/whisper/`) is the whisper.cpp engine. Its collaborators are contracts with fakes beside them: `ModelFetcher` (the download), `PcmDecoder` (the slice of a kept recording as 16 kHz mono float samples), `ModelStorage` (the models directory and the phone's memory), and `WhisperRuntime` (inference). `FfiWhisperRuntime` runs the shim on one worker isolate that owns the whisper context, so a run blocks nothing else and a cancel reaches it through an abort flag in native memory. `whisper_catalog.dart` holds the five models (file, size, sha256, a peak memory figure and a batch budget factor set by hand) and the 100-language table in whisper's token order with the BCP-47 tag each resolves to (every model carries the first 99; the large-v3 family adds Cantonese); `tool/whisper/catalog.sh` in the host app is the only source of the sizes and hashes. A model counts as installed when its file's length matches the catalog; the hash was verified at download.

`WhisperShim` binds `ios/transcriber/Sources/WhisperShim/include/otr_whisper.h`, a flat C surface over whisper.cpp compiled into this package against the prebuilt `whisper.xcframework`. The binary is never in the checkout: run `tool/whisper/fetch.sh` in the host app once before an iOS build; it pins the release tag and the zip hash. `TranscriberPlugin.register` references the shim so the linker keeps its object file, the host app's Release configuration keeps global symbols through the strip step, and Dart resolves them from the process image. The shim runs whisper on the GPU on a device and on the CPU in the simulator, whose Metal driver traps on a model's buffers.

An Android build inherits the engine, the fetcher, the catalog and the runtime unchanged; it needs the shim compiled through the plugin's CMake, a MediaCodec `PcmDecoder` and a `ModelStorage` behind the same three channel methods, and the plugin's capture, compose and playback half.

The classic recognizer hands out only its current utterance, and resets that
hypothesis after a pause of about two seconds. `UtteranceStitcher` rebuilds the
whole take from those pieces, and `feedHolds` paces the file feeder that drives
it. Both live in `ios/transcriber/Core`, a Swift package with no Flutter
dependency, so `swift test` can reach the rules;
`tool/checks.sh` in the host app runs them. Keep it free of iOS-only API: those
tests build for the host.
