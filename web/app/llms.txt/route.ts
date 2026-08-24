import { SITE_URL, GITHUB_URL, APP_STORE_URL, SITE_TAGLINE } from "@/lib/site";

export const dynamic = "force-static";

export function GET() {
  const body = `# OpenTranscribe

> ${SITE_TAGLINE} You speak, it transcribes on the device, and nothing ever leaves the phone.

OpenTranscribe is an open source voice journal for iOS. It records audio natively, shows a live transcript while you speak, and transcribes the full recording on the device when you stop. Apple Intelligence reads the entries and writes a short reflection for every day, week, and month, entirely on the device. There is no network layer in the app: no requests, no sockets, no third-party SDKs, no analytics, and no accounts. It works the same in airplane mode. Entries are stored encrypted on the phone. Speech models are downloaded once per language and recognition runs entirely on the handset. Raw audio is kept by default so an entry can be transcribed again later by a better engine, and with keeping off each recording is deleted after its first transcription. Transcripts can be edited in place, with a revision history that keeps every prior version. The whole journal backs up to one passphrase-sealed archive file and restores from it. A lock screen control, a widget, and Siri through App Intents start a recording without opening the app.

## Links

- Homepage: ${SITE_URL}
- App Store: ${APP_STORE_URL}
- How it works: ${SITE_URL}/#record
- Reflections: ${SITE_URL}/#reflections
- OpenTranscribe Club: ${SITE_URL}/#club
- Privacy, as enforced by the code: ${SITE_URL}/privacy
- Changelog: ${GITHUB_URL}/blob/main/CHANGELOG.md
- License: ${GITHUB_URL}/blob/main/LICENSE
- Source code (MIT licensed): ${GITHUB_URL}
- Issues: ${GITHUB_URL}/issues

## Facts

- Platform: iOS only, built with Flutter
- Transcription: on-device, engine-agnostic; the app refuses any engine that does not declare it runs on the device. Two engines ship, Apple Speech (iOS 26) and Apple Dictation (the classic recognizer), switchable in the app
- Reflections: written by on-device Apple Intelligence for each day, week, and month; silence is a valid result
- Audio: recordings stay in the native capture layer; only file paths, durations, levels, and text cross into the app
- Storage: entries encrypted at rest on the phone
- Backup: one archive file restores the whole journal, sealed with a passphrase by default; free, never behind the paywall
- Exports: the journal as Markdown, Obsidian notes, or a standalone website, part of the optional OpenTranscribe Club
- Club: a $25 one-time purchase that supports the app; direct StoreKit with no purchase SDK, no account, and no server
- Editing: transcripts edit in place, with a restorable revision history
- Quick start: lock screen control, widget row, Siri and Shortcuts through App Intents
- Network: none; the app ships without networking code
- License: MIT
- Distribution: App Store, iPhone, iOS 17 or newer
`;

  return new Response(body, {
    headers: { "Content-Type": "text/plain; charset=utf-8" },
  });
}
