<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/readme/banner-dark.svg">
  <img alt="opentranscribe, an offline voice journal for iOS, recorded and transcribed entirely on-device" width="560" src="assets/readme/banner-light.svg">
</picture>

<br/>

<p>
  <a href="pubspec.yaml"><img alt="Flutter" src="https://img.shields.io/badge/flutter-3.44%2B-02569B?logo=flutter&logoColor=white"></a>
  <a href="pubspec.yaml"><img alt="Dart" src="https://img.shields.io/badge/dart-3.12%2B-0175C2?logo=dart&logoColor=white"></a>
  <a href="ios/"><img alt="Platform" src="https://img.shields.io/badge/platform-iOS%2017%2B-000000?logo=apple&logoColor=white"></a>
  <a href="LICENSE"><img alt="License" src="https://img.shields.io/badge/license-MIT-blue"></a>
</p>

opentranscribe is a voice journal for iOS with no network layer. Capture, transcription, and storage all happen on the device, and there is no account, no sync, no telemetry, and no code path anywhere in the app that opens a socket. Airplane mode is not a supported mode, it is the only mode there is.

Transcription sits behind one contract, `TranscriptionEngine`. Apple's Speech framework is the first implementation, `SpeechAnalyzer` on iOS 26 and `SFSpeechRecognizer` below it, and whisper.cpp is meant to land as a second one without the rest of the app noticing. An engine that does not declare itself on-device is refused at construction, so the offline guarantee is a property of the code.

Live text is painted while you speak and then thrown away. What gets saved is a batch pass over the finished file, which is why the raw audio is kept: any entry can be transcribed again later, in another language or by a better engine. Speech models are per-language and live on the device, so the Models screen manages them, including the cap iOS 26 puts on how many languages one app may hold.

## Data on disk

Recordings are AAC in the app's own directory, written with iOS data protection and excluded from iCloud and device backups by default. Entries are encrypted JSON in the local key-value store, AES-256-CBC with a fresh IV per record. The encryption key is a build-time secret, not a value in the repo. See [SECURITY.md](SECURITY.md) for the trust model.

## Build

Flutter 3.44 or newer, Xcode, and an iOS 17+ target. Prefer a real device: the microphone, the speech models, and the Live Activity only partly work in the simulator.

```sh
flutter pub get
flutter run -d ios
```

Debug builds fall back to a development storage key. A release build refuses to start without a real one:

```sh
flutter run --release --dart-define=STORAGE_KEY=<your-32-char-key>
```

## Development

```sh
flutter analyze      # must be clean
flutter test         # must be green
dart format .        # 100 columns
flutter gen-l10n     # after editing lib/l10n/app_en.arb
```

Two layers, `lib/core/` for everything non-UI and `lib/view/` for the rest, with dependencies as typed fields on one composition root. The app imports neither `material.dart` nor `cupertino.dart`, draws every control itself, and has no widget tests. [CLAUDE.md](CLAUDE.md) is the full working contract.

## Contributing

Issues and pull requests are welcome; anything opening a socket does not belong here. Participation is governed by our [Code of Conduct](CODE_OF_CONDUCT.md), and security issues have a private channel in [SECURITY.md](SECURITY.md).

opentranscribe is MIT-licensed. See [LICENSE](LICENSE).
