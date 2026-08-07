import { HERO_LEAD, GITHUB_URL } from "@/lib/site";
import Nav from "@/components/Nav";
import Background from "@/components/Background";
import ShotShelf from "@/components/ShotShelf";
import FeatureFrame from "@/components/FeatureFrame";
import Footer from "@/components/Footer";
import Reveal from "@/components/Reveal";
import { GithubIcon } from "@/components/Icons";

const container = "mx-auto w-full max-w-frame px-6 sm:px-12";

export default function Home() {
  return (
    <>
      <Nav />
      <main id="top">
        <div className="relative overflow-hidden">
          <Background />
          <div className={`relative z-10 ${container} pt-36 sm:pt-44`}>
            <h1 className="boot boot-1 t-display max-w-[880px]">{HERO_LEAD}</h1>
            <p className="boot boot-2 t-body mt-6 max-w-[560px] text-ink-2">
              Nothing ever leaves the phone. It works the same in airplane mode.
            </p>
            <div className="boot boot-3 mt-9 flex flex-wrap items-center gap-6">
              <a href={GITHUB_URL} target="_blank" rel="noreferrer" className="btn">
                <GithubIcon className="h-4 w-4" />
                Read the source
              </a>
              <a
                href="#record"
                className="t-subhead transition-colors duration-200 hover:text-ink"
              >
                How it works ↓
              </a>
            </div>
          </div>

          <div className="boot boot-4 relative z-10 mt-20 sm:mt-24">
            <ShotShelf />
          </div>
        </div>

        <section className="mt-28 border-t border-line sm:mt-36">
          <FeatureFrame />
        </section>

        <section id="privacy" className="scroll-mt-24 border-t border-line">
          <div className={`${container} py-24 sm:py-32`}>
            <Reveal className="max-w-[720px]">
              <p className="t-eyebrow">Privacy</p>
              <h2 className="t-display mt-6 max-w-[600px]">Nothing ever leaves your phone.</h2>
              <div className="mt-8 space-y-5">
                <p className="t-body text-ink-2">
                  Recording, transcription, reflection, and storage all happen on the device, and
                  the app works the same in airplane mode.
                </p>
                <p className="t-body text-ink-2">
                  There are no requests, no sockets, and no third-party SDKs; there is no
                  networking code in the app at all. Recordings stay in the native capture layer,
                  and only file paths, durations, levels, and text ever cross into it. Every
                  transcription and reflection engine has to declare that it runs on the device,
                  and the app refuses any that does not. Entries are stored encrypted on the
                  phone. There are no analytics, no crash reporting, and no accounts.
                </p>
                <p className="t-body text-ink-2">
                  A claim like that cannot be backed by a privacy policy, only by source you can
                  read. The code is public and MIT licensed.
                </p>
              </div>
              <a
                href={GITHUB_URL}
                target="_blank"
                rel="noreferrer"
                className="t-subhead mt-8 inline-flex items-center gap-2 text-ink transition-colors duration-200 hover:text-ink-2"
              >
                <GithubIcon className="h-4 w-4" />
                Read the source →
              </a>
            </Reveal>
          </div>
        </section>
      </main>
      <Footer />
    </>
  );
}
