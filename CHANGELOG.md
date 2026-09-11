# Changelog

All notable changes to opentranscribe are documented here. Each release section below is what ships as the GitHub Release notes.

## 0.5.0 - Unreleased

A third engine, Whisper, that runs every language from one model you pick, on any iPhone.

- Whisper: whisper.cpp joins SpeechAnalyzer and Dictation on the transcription screen. Pick it, pick a model (Tiny, Base, Small, Medium, or Large Turbo, each with its size and a quality word), and one download serves the ninety-nine languages every model knows (Large Turbo adds Cantonese), including the ones the Apple engines have no model for. The live text stays off under Whisper; the transcript lands after you stop. The model card shows the download as it runs, dims a model too large for the phone, and lets you remove one you no longer want; the Cache screen counts what the models hold.
- The one connection: downloading a model is the only thing the app ever does over the network. It fetches a public file from one pinned host, resumes an interrupted download where it stopped, retries on its own when the connection breaks mid-way (leaving the app included; the screen says so while a download runs), verifies the file before it counts, and sends nothing. Everything else keeps working in airplane mode, and the one-rule test now holds the code to exactly that one file.
- Faster with the Neural Engine: a switch under the models fetches each model's Core ML encoder as a second download and prepares it once, so the encoder runs on the Neural Engine. Off deletes the encoders and keeps the models.
- Progress on a long pass: while Whisper transcribes, the entry shows how far the run is under its wait, and home's bar shows it for a take being saved, the model download ahead of it included. A hot phone gets fewer whisper threads from its next run on.
- VoiceOver names every control on a model card: the download, the ring with its percent, Use, In use, Cancel, Remove, and a failed download's reason.

## 0.4.1 - 2026-09-09

Development-only code is gone from the shipped app.

- Three switches that only ever served development have been taken out of the code: a build flag that forced the pre-iOS 26 chrome on, a hidden long-press on the transcription screen that stamped fake model failures, and an unused query flag that could reopen onboarding. Nothing in the app could reach any of them, and none of them exist now.
- The native toggle carried fallback paths that reached UIKit by selector name, for a control the plugin never builds. They could not run; the toggle is a UISwitch and the code now says so plainly.

## 0.4.0 - 2026-09-02

Faster everywhere, a clearer backup screen, dictation that keeps what you said before a pause, a new first run, and polish across the app.

- Speed, everywhere the journal is read: the app no longer re-decrypts your whole journal after every rename, edit, delete, or landed re-transcription, and it decrypts on a worker thread before the first read, so a long journal stays as quick as a short one and the list is there when the splash lifts. Scrolling home, the live transcript, and reflections all stop redoing work they had already done.
- The backup screen redesigned: it opens by saying what a backup holds and roughly what it weighs, each format is its own action, Export as Markdown, Obsidian Vault, or Website, with one switch for whether recordings ride along, and packing runs off the interface thread with a live percent and a cancel. Passphrase fields can be revealed while you type them.
- Restore is honest about what it does: an entry that already exists takes the backup's version, you see what the backup holds before you commit, and the summary afterwards splits what was added, what was replaced, and what was already there. Failures name their cause instead of guessing, and the Website export speaks your language rather than shipping English to every locale.
- Onboarding reworked as four short pages built from the app's own parts instead of a list of icons: a take running with the recorder's own wave and live text, your week read back (on iPhones with Apple Intelligence), yours in any shape (the export formats and the sealed backup), then set up, where reflections, the microphone, speech recognition, and reminders sit as live rows and Get started asks for them, so saying yes to reminders there turns them on. You can swipe back and tap the dots; forward stays on the button. A permission you denied offers Settings where you hit the wall and the first entry you open points once at its menu.
- Dictation keeps what you said before a pause. Stopping for a couple of seconds used to make the recognizer start over, and everything before the pause was dropped from the live text and from the saved entry; every sentence of a take is now kept, in order, once each. Re-transcribing a long entry no longer stalls out, an entry whose recording is gone says so instead of failing generically, and live text in Japanese and Chinese wraps across lines instead of running off the edge.
- Polish across the app: the glass bar buttons answer a tap in the hand like every other control, and so do a scrub and a tap on an entry's wave. Editing a transcript, a title, or a passphrase now works the way iOS text does, with a tap to place the caret, the magnifier, handles, and the edit menu (so a password manager can paste); a transcript and a title capitalize their sentences, and dragging the page puts the keyboard away. Changing the app language moves the reflection reminders to the new week and words at once. The app stays portrait. VoiceOver names every bar button, floating disc, switch, and segment, and hears notices instead of watching them fade; faded live text and inert calendar days read at 3:1 in every theme, and follow Increase Contrast.

## 0.3.0 - 2026-08-31

Say more into an entry you already saved, re-hear the whole journal with a better engine, and dress the app in a look of your own.

- Continue an entry: record more onto a saved entry from its own screen. The audio merges into the kept recording and the transcript grows to match, edits kept, and the new words shimmer into place where they land. A take in another language gets the language marker. An entry with no recording can be continued too; the take becomes its recording. A take that cannot be merged is saved as its own entry, never lost. (#6)
- Re-transcribe all: a bulk runner over the whole journal, seated under the engine picker on the transcription screen, that lets the engine you switched to re-hear the entire history. Live animated progress with cancel, and resume is free: a run skips whatever the current engine already transcribed, so stopping loses nothing. It waits for a live recording and pauses while the device runs hot. (#8)
- Every feature is free, including the formatted exports the club used to gate. What the OpenTranscribe Club unlocks from here on is looks, and nothing else.
- Club themes: every family beyond Default is a club look. Gruvbox and Sepia stay, and five join them: Midnight, Dracula, Nord, Catppuccin, and Tokyo Night. Solarized is retired. A pick is kept whether or not the club covers it, so it snaps on the moment a membership lands.
- Club app icons: three alternate home screen icons, Signal, Lines, and Dots, picked on the appearance screen above the themes. A club look, like the families.
- The appearance screen holds both pickers now: the app icons over one grid of every theme, with light, dark, and system moved into the bar's own menu. Tapping a club look you have not joined for opens the club, and joining wears the look you tapped.
- The club opens as a sheet over whatever you were doing, rather than taking you to a screen of its own.

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
