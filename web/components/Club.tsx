import Image from "next/image";
import { CLUB, SITE_NAME } from "@/lib/site";
import DitherCorner from "./DitherCorner";
import { WaveMark } from "./Wordmark";

function Swatch({ colors }: { colors: readonly [string, string, string, string] }) {
  const [background, surface, text, accent] = colors;
  return (
    <span className="flex h-full flex-1 flex-col justify-between p-2.5" style={{ background }}>
      <span className="h-1.5 w-1.5 rounded-full" style={{ background: accent }} />
      <span className="flex flex-col gap-1">
        <span className="h-[3px] w-full rounded-full" style={{ background: text }} />
        <span className="h-[3px] w-2/3 rounded-full" style={{ background: text, opacity: 0.5 }} />
        <span className="mt-1 h-2.5 w-full rounded-[4px]" style={{ background: surface }} />
      </span>
    </span>
  );
}

export default function Club() {
  return (
    <div className="panel relative overflow-hidden">
      <DitherCorner className="pointer-events-none absolute right-0 top-0 h-[340px] w-[min(90%,620px)] [mask-image:linear-gradient(to_left,black_30%,transparent_85%)]" />
      <div className="relative grid gap-12 p-7 sm:p-10 lg:grid-cols-[minmax(0,5fr)_minmax(0,6fr)] lg:gap-14 lg:p-14">
        <div>
          <div className="flex items-center gap-3 text-ink">
            <WaveMark className="h-7 w-auto" />
            <div>
              <p className="text-[20px] font-semibold leading-none tracking-[-0.4px]">
                {SITE_NAME}
              </p>
              <p className="t-eyebrow mt-1.5 text-ink">{CLUB.tag}</p>
            </div>
          </div>
          <h2 className="t-display mt-9">{CLUB.title}</h2>
          <div className="mt-6 space-y-4">
            {CLUB.pitch.map((p) => (
              <p key={p} className="t-body max-w-[52ch] text-ink-2">
                {p}
              </p>
            ))}
          </div>
          <div className="mt-9 flex flex-wrap items-end gap-x-5 gap-y-2">
            <p className="t-price">{CLUB.price}</p>
            <div className="pb-1">
              <p className="t-subhead text-ink">{CLUB.priceNote}</p>
              <p className="t-footnote">{CLUB.priceRegion}</p>
            </div>
          </div>
        </div>

        <div>
          <p className="t-eyebrow pl-1">{CLUB.perksHead}</p>
          <div className="app-card mt-3 p-5 sm:p-6">
            <h3 className="t-body font-semibold">{CLUB.icons.title}</h3>
            <p className="t-footnote mt-1">{CLUB.icons.note}</p>
            <ul className="mt-5 grid grid-cols-4 gap-3 sm:gap-5">
              {CLUB.icons.items.map((icon) => (
                <li key={icon.name} className="text-center">
                  <Image
                    src={icon.src}
                    alt=""
                    width={256}
                    height={256}
                    sizes="96px"
                    className="aspect-square h-auto w-full rounded-[22.37%]"
                    draggable={false}
                  />
                  <p className={`t-footnote mt-2 ${icon.club ? "text-ink" : ""}`}>{icon.name}</p>
                </li>
              ))}
            </ul>
          </div>
          <div className="app-card mt-3 p-5 sm:p-6">
            <h3 className="t-body font-semibold">{CLUB.themes.title}</h3>
            <p className="t-footnote mt-1">{CLUB.themes.note}</p>
            <ul className="mt-5 grid grid-cols-3 gap-3 sm:grid-cols-4">
              {CLUB.themes.items.map((theme) => (
                <li key={theme.name}>
                  <span
                    className="flex aspect-[4/3] overflow-hidden rounded-[12px] ring-1 ring-line"
                    aria-hidden
                  >
                    <Swatch colors={theme.dark} />
                    <Swatch colors={theme.light} />
                  </span>
                  <p className="t-footnote mt-2 text-ink">{theme.name}</p>
                </li>
              ))}
            </ul>
          </div>
        </div>
      </div>
    </div>
  );
}
