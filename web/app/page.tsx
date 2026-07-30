import { HERO_LEAD, GITHUB_URL, PRIVACY } from "@/lib/site";
import Nav from "@/components/Nav";
import Background from "@/components/Background";
import Screenshots from "@/components/Screenshots";
import HowItWorks from "@/components/HowItWorks";
import Footer from "@/components/Footer";
import Reveal from "@/components/Reveal";
import { AnimatedWave } from "@/components/AnimatedWave";
import { GithubIcon } from "@/components/Icons";

const container = "mx-auto w-full max-w-frame px-6 sm:px-12";
const section = "border-t border-line";
const pad = "py-24 sm:py-32 lg:py-40";

export default function Home() {
  return (
    <>
      <Nav />
      <main id="top">
        <section className="relative overflow-hidden">
          <Background />
          <div className="relative z-10">
            <div className="relative mx-auto flex min-h-[78svh] max-w-3xl flex-col items-center justify-center px-6 pb-10 pt-28 text-center">
              <div
                aria-hidden
                className="pointer-events-none absolute inset-0 -z-10"
                style={{
                  background:
                    "radial-gradient(58% 46% at 50% 42%, rgba(0,0,0,0.72) 0%, rgba(0,0,0,0.4) 46%, transparent 72%)",
                }}
              />
              <div className="boot boot-1 flex items-center justify-center gap-3 sm:gap-4">
                <AnimatedWave className="h-9 w-auto sm:h-11" />
                <h1 className="hero-text text-4xl font-semibold tracking-tight sm:text-6xl">
                  OpenTranscribe
                </h1>
              </div>
              <p className="boot boot-2 t-lead hero-text mx-auto mt-6 max-w-[620px]">
                {HERO_LEAD}
              </p>
              <div className="boot boot-3 mt-9 flex flex-wrap items-center justify-center gap-3">
                <a href={GITHUB_URL} target="_blank" rel="noreferrer" className="btn">
                  <GithubIcon className="h-4 w-4" />
                  Read the source
                </a>
                <a href="#works" className="btn-ghost">
                  How it works
                </a>
              </div>
              <p className="boot boot-4 t-eyebrow hero-text mt-8">
                Not on the App Store yet · MIT licensed
              </p>
            </div>

            <div className={`${container} pb-24`}>
              <Screenshots />
            </div>
          </div>
        </section>

        <section id="works" className={section}>
          <div className={`${container} ${pad}`}>
            <Reveal className="mb-14 max-w-prose">
              <p className="t-eyebrow">01 / Mechanics</p>
              <h2 className="t-h1 mt-6">How a recording becomes an entry.</h2>
            </Reveal>
            <HowItWorks />
          </div>
        </section>

        <section id="privacy" className={section}>
          <div className={`${container} ${pad}`}>
            <div className="grid gap-10 lg:grid-cols-12 lg:gap-8">
              <Reveal className="lg:col-span-6">
                <p className="t-eyebrow">02 / Privacy</p>
                <h2 className="t-h1 mt-6">Privacy first is a property of the code.</h2>
                <p className="t-body mt-6 max-w-prose">
                  Recording, transcription, and storage all happen on the phone, and the app works
                  the same in airplane mode.
                </p>
                <p className="t-body mt-4 max-w-prose">
                  A claim like that cannot be backed by a privacy policy, only by source you can
                  read. The code is public and MIT licensed.
                </p>
                <a
                  href={GITHUB_URL}
                  target="_blank"
                  rel="noreferrer"
                  className="btn-ghost mt-8"
                >
                  <GithubIcon className="h-4 w-4" />
                  Read the source
                </a>
              </Reveal>
              <Reveal stagger className="overflow-hidden rounded-[10px] border border-line bg-surface-1 lg:col-span-6">
                {PRIVACY.map((row) => (
                  <div
                    key={row.claim}
                    className="grid gap-2 border-b border-line px-6 py-5 last:border-b-0 sm:grid-cols-[110px_1fr] sm:gap-6"
                  >
                    <span className="t-mono text-ink">{row.claim}</span>
                    <span className="t-body-s">{row.detail}</span>
                  </div>
                ))}
              </Reveal>
            </div>
          </div>
        </section>

      </main>
      <Footer />
    </>
  );
}
