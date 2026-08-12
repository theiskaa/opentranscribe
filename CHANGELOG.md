# Changelog

All notable changes to opentranscribe are documented here. Each release section below is what ships as the GitHub Release notes.

## 0.1.0 - 2026-08-12

The first release: a voice journal for iOS that works entirely on the device. There is no account, no sync, no telemetry, and no code in the app that opens a network connection.

- Recording with a live on-screen transcript, pause and resume, and a Live Activity on the lock screen and Dynamic Island while a take runs.
- On-device transcription through Apple's Speech framework (`SpeechAnalyzer` on iOS 26, `SFSpeechRecognizer` below it), behind a swappable engine contract that refuses any engine not declaring itself on-device. Per-language speech models are downloaded and removed from the Models screen; the transcription language is a setting, device locale by default.
- A journal grouped by day under a paging week strip. An entry plays back with a scrubber, marking the transcript as it plays, and can be renamed, re-transcribed after a language change or a better model, and swiped away.
- Reflections: short notes written on-device by Apple Foundation Models when a day, a week, or a month closes, each period its own stream, browsable by drilling from months into weeks into days. A quiet period is a valid result. The feature stays invisible on hardware without Apple Intelligence, and an optional local notification says when a new reflection is ready.
- Raw audio is kept by default so entries can be re-transcribed later; a keep-audio toggle discards a recording after its first successful transcription, and the Cache screen shows and reclaims what is kept.
- Everything at rest is encrypted: entries as AES-256-GCM records under a random per-device key held in the Keychain, recordings under iOS data protection, excluded from iCloud and device backups by default.
- Four theme families (default, Gruvbox, Solarized, Sepia), each in light, dark, or system mode, drawn entirely by the app; native Liquid Glass chrome on iOS 26.
- Eight languages: English, Chinese, French, German, Italian, Japanese, Korean, Portuguese.
- iPhone, iOS 17 or newer.
