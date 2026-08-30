# Changelog

All notable changes to opentranscribe are documented here. Each release section below is what ships as the GitHub Release notes.

## 0.3.0 - Unreleased

The whole journal re-heard by a better engine.

- Re-transcribe all: a bulk runner over the whole journal, seated under the engine picker on the transcription screen, that lets the engine you switched to re-hear the entire history. Live animated progress with cancel, and resume is free: a run skips whatever the current engine already transcribed, so stopping loses nothing. It waits for a live recording and pauses while the device runs hot. (#8)
- Continue an entry: record more onto a saved entry from its own screen. The audio merges into the kept recording and the transcript grows to match, edits kept; a take in another language gets the language marker. An entry with no recording can be continued too; the take becomes its recording. A take that cannot be merged is saved as its own entry. (#6)
- Formatted exports and re-transcribe all are free for everyone. The club no longer gates any feature; what it unlocks from here on is looks: theme families.
- Club themes: every family beyond Default is a club look. Gruvbox and Sepia stay, and five join them: Midnight, Dracula, Nord, Catppuccin, and Tokyo Night. Solarized is retired. A pick is kept whether or not the club covers it, so it snaps on the moment a membership lands.
- App icons: three alternate home screen icons, Signal, Lines, and Dots, free for everyone, picked on the appearance screen above the themes.

## 0.2.0 - 2026-08-25

Backups, editing, the club, engine choice, and faster ways to start a recording.

- Formatted exports, the first OpenTranscribe Club feature: the whole journal handed to the share sheet as Markdown, as Obsidian notes, or as a Website that opens with a player in any browser. (#5)
- Native archive backup: one file that restores the whole journal, audio and reflections included, sealed with a passphrase by default; without it the file is unreadable. Free for everyone, never behind the paywall, so anyone can always back up and recover. (#5)
- The OpenTranscribe Club, an optional one-time purchase that supports the app: club features start with the formatted exports, and whatever joins the club later is included. Direct StoreKit 2 with no purchase SDK, no account, and no server: the entitlement is verified on-device from Apple's own record, membership works in airplane mode, and no journal content is in the purchase conversation.
- Manual transcript editing, in place on the entry screen, with a revision history that keeps every prior version and lets one be restored. (#14)
- A lock screen control and a widget row that start a recording without opening the app, plus Siri and Shortcuts support through App Intents. (#9)
- The launch splash is now drawn natively and plays over the boot, replacing the earlier Flutter splash screen.
- Notifications: a master switch for reflection reminders, a toggle per period (day, week, month) for which ones nudge, and one shared time.
- Engine choice: the transcription screen lists every engine the app ships, SpeechAnalyzer (the iOS 26 engine) and Dictation (the classic recognizer the system's dictation uses), each described in one line and switchable with a tap. An engine the device cannot run stays visible, dimmed, with the reason; a new engine lands as one more row.
- The transcription screen redesigned around the language you speak: the default language is a card with an honest status line (ready and naming the engine that answers, download progress, or what stands in the way), the other ready languages are chips a tap makes the default, and the whole library moved into a sheet where languages are added, removed, and switched in one place.
- iPhones whose hardware cannot run SpeechAnalyzer (the iPhone 11 family and earlier chips) no longer show an empty language list: they start on Dictation and transcribe normally.
- Under Dictation, a language whose system dictation model is missing says so and points at the iOS keyboard settings, instead of claiming it is ready.
- Reliability around engine switches: a switch landing mid-download, mid-removal, or mid-load can no longer leave one engine's status, failure badge, or download progress on the other engine's language rows; queued model downloads survive a cancelled predecessor; and a blocked install whose slot-holders have since left offers a retry instead of a dead end.

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
