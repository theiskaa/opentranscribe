import { SITE_URL, GITHUB_URL, SITE_TAGLINE } from "@/lib/site";

export const dynamic = "force-static";

export function GET() {
  const body = `# OpenTranscribe

> ${SITE_TAGLINE} You speak, it transcribes on the device, and nothing ever leaves the phone.

OpenTranscribe is an open source voice journal for iOS. It records audio natively, shows a live transcript while you speak, and transcribes the full recording on the device when you stop. There is no network layer in the app: no requests, no sockets, no third-party SDKs, no analytics, and no accounts. It works the same in airplane mode. Entries are stored encrypted on the phone. Speech models are downloaded once per language and recognition runs entirely on the handset. Raw audio is kept by default so an entry can be transcribed again later by a better engine, and with keeping off each recording is deleted after its first transcription.

## Links

- Homepage: ${SITE_URL}
- How it works: ${SITE_URL}/#works
- Privacy, as enforced by the code: ${SITE_URL}/#privacy
- Source code (MIT licensed): ${GITHUB_URL}
- Issues: ${GITHUB_URL}/issues

## Facts

- Platform: iOS only, built with Flutter
- Transcription: on-device, engine-agnostic; the app refuses any engine that does not declare it runs on the device
- Audio: recordings stay in the native capture layer; only file paths, durations, levels, and text cross into the app
- Storage: entries encrypted at rest on the phone
- Network: none; the app ships without networking code
- License: MIT
- Distribution: not on the App Store yet
`;

  return new Response(body, {
    headers: { "Content-Type": "text/plain; charset=utf-8" },
  });
}
