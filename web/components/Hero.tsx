import Image from "next/image";
import {
  APP_STORE_URL,
  CTA,
  GITHUB_URL,
  HERO_FACTS,
  HERO_LEAD,
  HERO_SIDES,
  HERO_TITLE,
} from "@/lib/site";
import Recorder from "@/components/recorder/Recorder";
import DitherCorner from "./DitherCorner";
import { AppleIcon, GithubIcon } from "./Icons";

function Side({ shot, className }: { shot: (typeof HERO_SIDES)[number]; className: string }) {
  return (
    <div className={`hero-side hidden w-full max-w-[280px] opacity-40 lg:block ${className}`}>
      <Image
        src={shot.src}
        alt={shot.alt}
        width={560}
        height={976}
        sizes="280px"
        className="h-auto w-full select-none"
        draggable={false}
      />
    </div>
  );
}

export default function Hero() {
  const [left, right] = HERO_SIDES;
  return (
    <div className="relative overflow-hidden">
      <DitherCorner
        from="top"
        className="pointer-events-none absolute inset-x-0 top-0 h-[640px] w-full"
      />
      <div className="relative mx-auto w-full max-w-frame px-6 pt-28 sm:px-12 sm:pt-36">
        <div className="flex flex-col items-center text-center">
          <h1 className="t-hero max-w-[14em]">{HERO_TITLE}</h1>
          <p className="t-lead mt-6 max-w-[52ch] text-ink-2">{HERO_LEAD}</p>
          <div className="mt-9 flex flex-wrap items-center justify-center gap-3">
            <a href={APP_STORE_URL} target="_blank" rel="noreferrer" className="btn">
              <AppleIcon className="h-4 w-4" />
              {CTA.download}
            </a>
            <a href={GITHUB_URL} target="_blank" rel="noreferrer" className="btn-ghost">
              <GithubIcon className="h-4 w-4" />
              {CTA.source}
            </a>
          </div>
          <ul className="t-footnote mt-7 flex flex-wrap justify-center gap-x-6 gap-y-1.5 text-ink-3">
            {HERO_FACTS.map((fact) => (
              <li key={fact}>{fact}</li>
            ))}
          </ul>
        </div>

        <div className="hero-stage mt-16 grid h-[480px] grid-cols-[minmax(0,330px)] overflow-hidden sm:h-[540px] items-start justify-center gap-10 lg:grid-cols-[1fr_minmax(0,330px)_1fr]">
          <Side shot={left} className="mt-24 justify-self-end" />
          <div className="mx-auto w-full max-w-[300px] sm:max-w-[330px]">
            <Recorder controls={false} />
          </div>
          <Side shot={right} className="mt-24 justify-self-start" />
        </div>
      </div>
    </div>
  );
}
