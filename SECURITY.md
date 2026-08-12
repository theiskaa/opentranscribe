# Security Policy

opentranscribe is a private, offline voice journal. It records audio, transcribes and reflects on it on-device, and stores everything locally. It makes no network calls and has no server, no account, and no analytics. The bugs that matter most here are the ones that would send data off the device or expose the journal on it. Reports are appreciated.

## Reporting a vulnerability

**Please do not open a public issue for a security problem.**

Report privately through GitHub's [private vulnerability reporting](https://github.com/theiskaa/opentranscribe/security/advisories/new), the "Report a vulnerability" button under the repository's **Security** tab. If you cannot use that, email **me@theiskaa.com** with the details.

A useful report includes:

- the version or commit you tested,
- your device and OS version,
- a clear description of the issue and its impact,
- the steps to reproduce it (a minimal proof of concept helps),
- and any thoughts on a fix, if you have them.

Please give a reasonable window to investigate and address the issue before any public disclosure. You will get an acknowledgement, updates as the fix progresses, and credit in the release notes if you would like it.

## Trust model

A few design choices define what security means here:

- **Nothing leaves the device.** The app has no network layer and is meant to work with the phone in airplane mode. Recording, transcription, reflection, and storage all happen on-device. Any code path, dependency, or SDK that opens a network connection or transmits data off-device is a bug, and the most serious kind in this app. The supporter purchase goes through StoreKit: the OS talks to the App Store, no journal content is in that conversation, and entitlements are verified on-device.
- **Your data lives on your device.** Audio and transcripts are stored in the app's own on-device storage. Entries and settings are encrypted at rest with AES-256-GCM through `LocalService`, under a random 32-byte key generated on first launch and held in the Keychain (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`). That key never appears in the binary and never leaves the device. Records written before the device key existed migrate to the new format in place at launch. `STORAGE_KEY`, a build-time secret, remains only to read and migrate those pre-migration records.
- **The engines are on-device and swappable.** Transcription runs on Apple's Speech framework, reached through a platform channel, and a vendored whisper.cpp engine may follow. Reflection runs on Apple's Foundation Models, on-device, with no Private Cloud Compute fallback. Both live in app-owned plugin packages, `packages/transcriber` and `packages/reflections`, behind contracts that refuse an engine which does not declare itself on-device, and neither uploads audio.

## Areas of particular interest

The surfaces where a vulnerability would matter most:

- **Anything that reaches the network.** A direct or transitive dependency, a platform-channel call, or any code that opens a socket, resolves a host, or sends telemetry. A confirmed off-device transmission is the most serious report this project can get.
- **Data at rest.** How audio files and transcripts are written and protected on the device, file permissions and iOS Data Protection settings, and the `LocalService` encryption and its key handling.
- **The native bridge.** The platform-channel code in `packages/transcriber` and `packages/reflections` between Dart and the native Speech and Foundation Models frameworks (and later the vendored whisper.cpp), including audio buffer handling and any memory safety in native code.
- **Untrusted-input parsers.** Audio and any imported or exported data decoded by the app or the transcription engine. A crash, an out-of-bounds read, or unbounded memory growth on crafted input is in scope.
- **The supply chain.** A pub dependency or a future vendored engine that introduces a network call, telemetry, or unexpected data collection.

## What is not a vulnerability

- Data being readable by someone who already has your unlocked device, or through a full device backup you created. On-device data protection follows the platform sandbox; a compromised or jailbroken OS is out of scope.
- The reflection model producing wrong, offensive, or low-quality output. That is model behavior, not a security issue.
- Building a debug binary without supplying `--dart-define=STORAGE_KEY` and getting the documented development placeholder key. Shipping a release without a real key is a build misconfiguration, not a defect in the app.
