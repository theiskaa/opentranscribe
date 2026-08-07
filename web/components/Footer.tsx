import Link from "next/link";
import { GITHUB_URL, SITE_TAGLINE } from "@/lib/site";
import { WaveMark } from "./Wordmark";

function FooterLink({ href, label }: { href: string; label: string }) {
  const className = "t-footnote transition-colors duration-200 hover:text-ink";
  if (href.startsWith("http")) {
    return (
      <a href={href} target="_blank" rel="noreferrer" className={className}>
        {label}
      </a>
    );
  }
  return (
    <Link href={href} className={className}>
      {label}
    </Link>
  );
}

const COLS = [
  {
    head: "Product",
    links: [
      { label: "How it works", href: "/#record" },
      { label: "Reflections", href: "/#reflections" },
      { label: "Privacy", href: "/#privacy" },
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
    <footer>
      <div className="mx-auto w-full max-w-frame px-6 sm:px-12">
        <div className="rule-fade" />
        <div className="grid gap-14 py-20 lg:grid-cols-12 lg:gap-8">
          <div className="lg:col-span-5">
            <div className="flex items-center gap-3 text-ink">
              <WaveMark className="h-[16px] w-auto" />
              <span className="t-body font-semibold">OpenTranscribe</span>
            </div>
            <p className="t-footnote mt-4 max-w-xs">{SITE_TAGLINE}</p>
          </div>

          <div className="grid grid-cols-2 gap-8 sm:gap-12 lg:col-span-6 lg:col-start-8">
            {COLS.map((col) => (
              <div key={col.head}>
                <p className="t-eyebrow mb-5">{col.head}</p>
                <ul className="space-y-3">
                  {col.links.map((l) => (
                    <li key={l.label}>
                      <FooterLink href={l.href} label={l.label} />
                    </li>
                  ))}
                </ul>
              </div>
            ))}
          </div>
        </div>
      </div>
    </footer>
  );
}
