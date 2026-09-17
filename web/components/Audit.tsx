import { AUDIT, GITHUB_URL } from "@/lib/site";
import Sf, { type SfName } from "./Sf";

const SPANS = [
  "",
  "md:col-span-3",
  "md:col-span-3",
  "md:col-span-2",
  "md:col-span-2",
  "md:col-span-2",
];

function Files({ files }: { files: readonly string[] }) {
  return (
    <ul className="mt-auto flex min-w-0 flex-col gap-2 pt-7">
      {files.map((file) => (
        <li key={file}>
          <a
            href={`${GITHUB_URL}/blob/main/${file}`}
            target="_blank"
            rel="noreferrer"
            title={file}
            className="t-path group flex items-center gap-2 rounded-[12px] border border-line bg-canvas px-3 py-2.5 text-ink-2 transition-colors duration-200 hover:border-ink-3 hover:text-ink"
          >
            {/* Cut from the front, so the file's own name is what stays. */}
            <span className="min-w-0 flex-1 overflow-hidden text-ellipsis whitespace-nowrap text-left [direction:rtl]">
              <bdi>{file}</bdi>
            </span>
            <Sf
              name="arrowUpRight"
              className="nudge h-3 w-3 flex-none text-ink-3 group-hover:text-ink"
            />
          </a>
        </li>
      ))}
    </ul>
  );
}

function Tile({ icon }: { icon: SfName }) {
  return (
    <span className="grid h-12 w-12 flex-none place-items-center rounded-[14px] bg-ink/[0.06] text-ink">
      <Sf name={icon} className="h-6 w-6" />
    </span>
  );
}

export default function Audit() {
  const [first, ...rest] = AUDIT.rows;
  const { ledger } = AUDIT;
  return (
    <div className="mt-12 grid gap-4 md:grid-cols-6">
      <article className="grid min-w-0 gap-10 panel p-7 sm:p-9 md:col-span-6 lg:grid-cols-2 lg:gap-14 lg:p-12">
        <div className="flex min-w-0 flex-col">
          <Tile icon={first.icon} />
          <h3 className="t-title mt-6 max-w-[24ch]">{first.claim}</h3>
          <p className="t-body mt-3 max-w-[48ch] text-ink-2">{first.held}</p>
          <Files files={first.files} />
        </div>
        <div className="min-w-0 self-center app-card">
          <p className="t-footnote border-b border-line px-5 py-3.5 text-ink-3">{ledger.head}</p>
          <ul>
            {ledger.rows.map((name) => (
              <li key={name} className="flex items-center gap-3 border-b border-line px-5 py-3.5">
                <Sf name="xmark" className="h-3.5 w-3.5 flex-none text-ink-3" />
                <span className="t-subhead flex-1 text-ink-2">{name}</span>
                <span className="t-footnote">{ledger.never}</span>
              </li>
            ))}
            <li className="flex items-center gap-3 px-5 py-4">
              <Sf name="checkmark" className="h-3.5 w-3.5 flex-none text-ink" />
              <span className="t-subhead flex-1 font-semibold text-ink">{ledger.one.name}</span>
              <span className="t-footnote text-right text-ink-2">{ledger.one.note}</span>
            </li>
          </ul>
        </div>
      </article>

      {rest.map((row, i) => (
        <article
          key={row.claim}
          className={`flex min-w-0 flex-col panel p-7 sm:p-9 ${SPANS[i + 1]}`}
        >
          <Tile icon={row.icon} />
          <h3 className="mt-6 text-[20px] font-semibold leading-[1.2] tracking-[-0.02em] text-ink">
            {row.claim}
          </h3>
          <p className="t-subhead mt-3">{row.held}</p>
          <Files files={row.files} />
        </article>
      ))}
    </div>
  );
}
