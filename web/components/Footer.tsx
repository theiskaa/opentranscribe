import { GITHUB_URL, SITE_URL, SITE_TAGLINE } from "@/lib/site";
import { WaveMark } from "./Wordmark";
import { GithubIcon } from "./Icons";

const COLS = [
  {
    head: "Product",
    links: [
      { label: "How it works", href: "#works" },
      { label: "Privacy", href: "#privacy" },
    ],
  },
  {
    head: "Source",
    links: [
      { label: "GitHub", href: GITHUB_URL },
      { label: "MIT License", href: `${GITHUB_URL}/blob/main/LICENSE` },
      { label: "Issues", href: `${GITHUB_URL}/issues` },
    ],
  },
];

export default function Footer() {
  return (
    <footer className="border-t border-line">
      <div className="mx-auto w-full max-w-frame px-6 py-20 sm:px-12 sm:py-24">
        <div className="grid gap-14 lg:grid-cols-12 lg:gap-8">
          <div className="lg:col-span-5">
            <div className="flex items-center gap-3 text-ink">
              <WaveMark className="h-[18px] w-auto" />
              <span className="text-[17px] font-semibold tracking-tight">OpenTranscribe</span>
            </div>
            <p className="t-body-s mt-5 max-w-xs">{SITE_TAGLINE}</p>
            <a href={GITHUB_URL} target="_blank" rel="noreferrer" className="btn mt-8">
              <GithubIcon className="h-4 w-4" />
              Read the source
            </a>
          </div>

          <div className="grid grid-cols-2 gap-8 sm:gap-12 lg:col-span-6 lg:col-start-8">
            {COLS.map((col) => (
              <div key={col.head}>
                <p className="t-eyebrow mb-5">{col.head}</p>
                <ul className="space-y-3.5">
                  {col.links.map((l) => (
                    <li key={l.label}>
                      <a
                        href={l.href}
                        target={l.href.startsWith("http") ? "_blank" : undefined}
                        rel={l.href.startsWith("http") ? "noreferrer" : undefined}
                        className="link-underline t-body-s hover:text-ink"
                      >
                        {l.label}
                      </a>
                    </li>
                  ))}
                </ul>
              </div>
            ))}
          </div>
        </div>

        <div className="mt-20 flex flex-col gap-2 border-t border-line pt-8 sm:flex-row sm:items-center sm:justify-between">
          <a href={SITE_URL} className="link-underline t-mono hover:text-ink">
            opentranscribe.xyz
          </a>
          <p className="t-eyebrow">© 2026 OpenTranscribe</p>
        </div>
      </div>
    </footer>
  );
}
