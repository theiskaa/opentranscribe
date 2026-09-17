import { APP_STORE_URL, CTA, GITHUB_URL, HERO_FACTS, HERO_LEAD, HERO_TITLE } from "@/lib/site";
import Recorder from "@/components/recorder/Recorder";
import { AppleIcon, GithubIcon } from "./Icons";

export default function Hero() {
  return (
    <div className="mx-auto grid w-full max-w-frame items-center gap-14 px-6 pb-24 pt-28 sm:px-12 sm:pt-36 lg:grid-cols-[minmax(0,1.15fr)_minmax(0,0.85fr)] lg:gap-12 lg:pb-32">
      <div>
        <h1 className="t-hero">{HERO_TITLE}</h1>
        <p className="t-lead mt-6 max-w-[46ch] text-ink-2">{HERO_LEAD}</p>
        <div className="mt-9 flex flex-wrap items-center gap-3">
          <a href={APP_STORE_URL} target="_blank" rel="noreferrer" className="btn">
            <AppleIcon className="h-4 w-4" />
            {CTA.download}
          </a>
          <a href={GITHUB_URL} target="_blank" rel="noreferrer" className="btn-ghost">
            <GithubIcon className="h-4 w-4" />
            {CTA.source}
          </a>
        </div>
        <ul className="t-footnote mt-7 flex flex-wrap gap-x-6 gap-y-1.5 text-ink-3">
          {HERO_FACTS.map((fact) => (
            <li key={fact}>{fact}</li>
          ))}
        </ul>
      </div>
      <div className="mx-auto w-full max-w-[300px] sm:max-w-[330px]">
        <Recorder />
      </div>
    </div>
  );
}
