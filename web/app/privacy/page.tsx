import type { Metadata } from "next";
import Nav from "@/components/Nav";
import Footer from "@/components/Footer";
import { GITHUB_URL } from "@/lib/site";

export const metadata: Metadata = {
  title: "Privacy Policy",
  description:
    "OpenTranscribe collects no data. Recording, transcription, and storage all happen on the device, with no network access.",
  alternates: { canonical: "/privacy" },
};

const UPDATED = "July 30, 2026";

const SECTIONS = [
  {
    head: "No network",
    body: [
      "The app has no networking code. It creates no accounts, contacts no servers, and includes no analytics, advertising, or crash-reporting SDKs. It functions identically with no internet connection.",
    ],
  },
  {
    head: "Everything stays on your device",
    body: [
      "Audio is recorded and stored locally. Transcripts are generated on the device and stored encrypted on the device.",
      "Nothing is uploaded, synced, or backed up to us, because there is no server on our side to receive it.",
    ],
  },
  {
    head: "Transcription runs on the device",
    body: [
      "The app requires its transcription engine to declare that it operates on-device, and it refuses any engine that does not. Your audio is never sent off the phone to be transcribed.",
    ],
  },
  {
    head: "Permissions",
    body: [
      "The app uses two permissions. Microphone access is used to record your voice. Speech recognition access is used to transcribe it on the device. Both are used only for those purposes.",
    ],
  },
  {
    head: "Your data, your control",
    body: [
      "We have no access to your recordings or transcripts and cannot retrieve, view, or delete them. You can delete them at any time from within the app.",
      "Because the app collects no data, there is nothing for us to store, share, correct, or export, and no third party receives any data.",
    ],
  },
];

export default function Privacy() {
  return (
    <>
      <Nav />
      <main className="mx-auto w-full max-w-prose px-6 pb-28 pt-32 sm:px-12 sm:pt-40">
        <p className="t-eyebrow">Privacy</p>
        <h1 className="t-display mt-6">Privacy Policy</h1>
        <p className="t-footnote mt-5">Last updated {UPDATED}</p>

        <p className="t-body text-ink-2 mt-12">
          OpenTranscribe does not collect, transmit, or share any personal data.
        </p>

        <div className="mt-4 divide-y divide-line border-t border-line">
          {SECTIONS.map((s) => (
            <section key={s.head} className="py-9">
              <h2 className="t-title">{s.head}</h2>
              {s.body.map((p) => (
                <p key={p} className="t-body mt-4">
                  {p}
                </p>
              ))}
            </section>
          ))}

          <section className="py-9">
            <h2 className="t-title">Verify it yourself</h2>
            <p className="t-body mt-4">
              The source code is public and MIT licensed, so every statement
              above can be checked directly against the code that runs on your
              phone.
            </p>
            <a
              href={GITHUB_URL}
              target="_blank"
              rel="noreferrer"
              className="t-footnote transition-colors duration-200 mt-6 inline-block hover:text-ink"
            >
              github.com/theiskaa/opentranscribe
            </a>
          </section>

          <section className="py-9">
            <h2 className="t-title">Contact</h2>
            <p className="t-body mt-4">
              Questions about this policy can be raised as an issue on the
              repository.
            </p>
            <a
              href={`${GITHUB_URL}/issues`}
              target="_blank"
              rel="noreferrer"
              className="t-footnote transition-colors duration-200 mt-6 inline-block hover:text-ink"
            >
              github.com/theiskaa/opentranscribe/issues
            </a>
          </section>
        </div>
      </main>
      <Footer />
    </>
  );
}
