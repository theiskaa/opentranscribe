import { GITHUB_URL, SITE_URL, SITE_TAGLINE } from "@/lib/site";
import { Wordmark } from "./Wordmark";

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
      <div className="mx-auto w-full max-w-frame px-6 py-20 sm:px-12">
        <div className="grid gap-12 sm:grid-cols-2 lg:grid-cols-4">
          <div className="lg:col-span-2">
            <Wordmark className="text-[15px] text-ink" />
            <p className="t-body-s mt-4 max-w-xs">{SITE_TAGLINE}</p>
          </div>
          {COLS.map((col) => (
            <div key={col.head}>
              <p className="t-eyebrow mb-4">{col.head}</p>
              <ul className="space-y-3">
                {col.links.map((l) => (
                  <li key={l.label}>
                    <a
                      href={l.href}
                      target={l.href.startsWith("http") ? "_blank" : undefined}
                      rel={l.href.startsWith("http") ? "noreferrer" : undefined}
                      className="t-body-s transition-colors hover:text-ink"
                    >
                      {l.label}
                    </a>
                  </li>
                ))}
              </ul>
            </div>
          ))}
        </div>

        <div className="mt-16 flex flex-col gap-2 border-t border-line pt-8 sm:flex-row sm:items-center sm:justify-between">
          <a href={SITE_URL} className="t-mono hover:text-ink">
            opentranscribe.xyz
          </a>
          <p className="t-eyebrow">© 2026 OpenTranscribe</p>
        </div>
      </div>
    </footer>
  );
}
