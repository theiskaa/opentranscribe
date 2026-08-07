# Security Policy

opentranscribe is a private, offline voice journal. It records audio, transcribes and reflects on it entirely on-device, and stores everything locally. It makes no network calls and has no server, no account, and no analytics. Because the whole promise is that nothing leaves the phone, the bugs that matter most are the ones that would break that promise or expose the journal on the device. Reports are appreciated.

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

## The trust model, so expectations are clear

A few design choices define what security means here:

- **Nothing leaves the device.** The app has no network layer by design and is meant to work fully in airplane mode. Recording, transcription, reflection, and storage all happen on-device. Any code path, dependency, or SDK that opens a network connection or transmits data off-device contradicts the entire point of the app, so that is the single sharpest edge and the highest-value class of bug.
- **Your data lives on your device.** Audio and transcripts are stored in the app's own on-device storage. Entries and settings are encrypted at rest with AES-256-GCM through `LocalService`, under a random 32-byte key generated on first launch and held in the Keychain (`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`). That key never appears in the binary and never leaves the device. Records written before the device key existed migrate to the new format in place at launch. `STORAGE_KEY`, a build-time secret, remains only to read and migrate those pre-migration records.
- **The transcription engine is on-device and swappable.** The first engine is Apple's on-device Speech framework, reached through a platform channel; a vendored whisper.cpp engine may follow. Neither uploads audio. The engine sits behind one contract, and no data ever routes through a remote service.

## Areas of particular interest

If you are looking for where the sharp edges are, these are the surfaces where a vulnerability would matter most:

- **Anything that reaches the network.** A direct or transitive dependency, a platform-channel call, or any code that opens a socket, resolves a host, or sends telemetry. Given the app's promise, a confirmed off-device transmission is the most serious bug there is.
- **Data at rest.** How audio files and transcripts are written and protected on the device, file permissions and iOS Data Protection settings, and the `LocalService` encryption and its key handling.
- **The native bridge.** The platform-channel code between Dart and the native Speech framework (and later the vendored whisper.cpp), including audio buffer handling and any memory safety in native code.
- **Untrusted-input parsers.** Audio and any imported or exported data decoded by the app or the transcription engine. A crash, an out-of-bounds read, or unbounded memory growth on crafted input is in scope.
- **The supply chain.** A pub dependency or a future vendored engine that introduces a network call, telemetry, or unexpected data collection.

## What is not a vulnerability

- Data being readable by someone who already has your unlocked device, or through a full device backup you created. On-device data protection follows the platform sandbox; a compromised or jailbroken OS is out of scope.
- The reflection model producing wrong, offensive, or low-quality output. That is model behavior, not a security issue.
- Building a debug binary without supplying `--dart-define=STORAGE_KEY` and getting the documented development placeholder key. Shipping a release without a real key is a build misconfiguration, not a defect in the app.
