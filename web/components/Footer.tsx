import Link from "next/link";
import { APP_STORE_URL, GITHUB_URL, SITE_TAGLINE } from "@/lib/site";
import { CHANGELOG, LICENSE, type Doc } from "@/lib/docs";
import { WaveMark } from "./Wordmark";
import DocLink from "./DocLink";

const linkClass = "t-footnote block text-left transition-colors duration-200 hover:text-ink";

type FooterItem = { label: string; href: string } | { doc: Doc };

function FooterEntry({ entry }: { entry: FooterItem }) {
  if ("doc" in entry) {
    return <DocLink doc={entry.doc} className={linkClass} />;
  }
  if (entry.href.startsWith("http")) {
    return (
      <a href={entry.href} target="_blank" rel="noreferrer" className={linkClass}>
        {entry.label}
      </a>
    );
  }
  return (
    <Link href={entry.href} className={linkClass}>
      {entry.label}
    </Link>
  );
}

const COLS: { head: string; links: FooterItem[] }[] = [
  {
    head: "Product",
    links: [
      { label: "Download", href: APP_STORE_URL },
      { label: "How it works", href: "/#record" },
      { label: "Supporter Club", href: "/#club" },
      { label: "Privacy", href: "/privacy" },
    ],
  },
  {
    head: "Source",
    links: [
      { label: "GitHub", href: GITHUB_URL },
      { doc: CHANGELOG },
      { doc: LICENSE },
      { label: "Issues", href: `${GITHUB_URL}/issues` },
    ],
  },
];

function keyOf(entry: FooterItem): string {
  return "doc" in entry ? entry.doc.file : entry.label;
}

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
                  {col.links.map((entry) => (
                    <li key={keyOf(entry)}>
                      <FooterEntry entry={entry} />
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
