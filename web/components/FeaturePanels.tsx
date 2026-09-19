import Image from "next/image";
import { FEATURES } from "@/lib/site";

const WIDE = new Set<string>(["record", "home"]);

export default function FeaturePanels() {
  return (
    <div className="mt-12 grid gap-4 md:grid-cols-2">
      {FEATURES.map((f, i) => {
        const wide = WIDE.has(f.id) || (i === FEATURES.length - 1 && FEATURES.length % 2 === 1);
        const flip = wide && i % 2 === 1;
        return (
          <article
            key={f.id}
            id={f.id}
            className={`panel flex scroll-mt-24 flex-col overflow-hidden ${
              wide
                ? `md:col-span-2 md:items-stretch ${flip ? "md:flex-row-reverse" : "md:flex-row"}`
                : ""
            }`}
          >
            <div
              className={`px-7 py-8 sm:px-9 sm:pt-9 ${wide ? "md:flex-1 md:self-center md:p-12" : ""}`}
            >
              <h3 className="t-title">{f.title}</h3>
              <p className="t-body mt-3 max-w-[52ch] text-ink-2">{f.body}</p>
              <p className="t-footnote mt-3 max-w-[52ch] text-ink-3">{f.foot}</p>
            </div>
            <div
              className={`panel-shot mt-auto flex justify-center ${
                wide ? "h-[340px] md:h-[400px] md:w-[42%] md:flex-none md:pt-10" : "h-[340px]"
              }`}
            >
              <Image
                src={f.shot}
                alt={f.cap}
                width={540}
                height={1100}
                sizes="270px"
                className="h-auto w-[270px] max-w-[80%] select-none self-start"
                draggable={false}
              />
            </div>
          </article>
        );
      })}
    </div>
  );
}
