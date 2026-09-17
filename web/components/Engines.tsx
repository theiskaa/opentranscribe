import { ENGINES } from "@/lib/site";
import { AppleIcon, OpenAIIcon } from "./Icons";
import Sf from "./Sf";

const MARKS = { apple: AppleIcon, openai: OpenAIIcon } as const;
const LEVELS = [1, 2, 3, 4, 5] as const;
const CARD_NAME = "text-[17px] font-semibold tracking-[-0.4px] text-ink";

type Engine = (typeof ENGINES.cards)[number];

function Head({ engine, wide = false }: { engine: Engine; wide?: boolean }) {
  const Mark = MARKS[engine.mark];
  return (
    <>
      <div className="flex items-center gap-4">
        <span className="grid h-12 w-12 flex-none place-items-center rounded-[14px] bg-ink/[0.06] text-ink">
          <Mark className="h-[22px] w-[22px]" />
        </span>
        <div className="min-w-0">
          <h3 className="t-title">{engine.name}</h3>
          <p className="t-footnote text-ink-3">{engine.maker}</p>
        </div>
      </div>
      <p className={`${wide ? "t-body" : "t-subhead"} mt-6 max-w-[46ch] text-ink-2`}>
        {engine.note}
      </p>
    </>
  );
}

function Facts({ engine, pinned = true }: { engine: Engine; pinned?: boolean }) {
  return (
    <ul className={`flex flex-wrap gap-2 pt-7 ${pinned ? "mt-auto" : ""}`}>
      {engine.facts.map((fact) => (
        <li
          key={fact.text}
          className="t-footnote flex items-center gap-2 rounded-full border border-line bg-canvas px-3 py-1.5 text-ink"
        >
          <Sf name={fact.icon} className="h-3.5 w-3.5 flex-none text-ink-2" />
          {fact.text}
        </li>
      ))}
    </ul>
  );
}

function Speaking({ engine }: { engine: Engine }) {
  return (
    <div className="mt-7">
      <div className="app-card flex items-center gap-4 p-4">
        <span className="text-[28px] leading-none" aria-hidden>
          {ENGINES.speaking.flag}
        </span>
        <div className="min-w-0 flex-1">
          <p className={CARD_NAME}>{ENGINES.speaking.language}</p>
          <p className="t-footnote mt-0.5">
            {ENGINES.speaking.ready} · {engine.name}
          </p>
        </div>
      </div>
      <div className="mt-2.5 flex flex-wrap gap-2">
        {ENGINES.alsoReady.map((language) => (
          <span
            key={language.name}
            className="app-card flex items-center gap-2 rounded-[12px] px-3 py-2 text-[13px] font-medium text-ink"
          >
            <span aria-hidden>{language.flag}</span>
            {language.name}
          </span>
        ))}
      </div>
    </div>
  );
}

function Models() {
  return (
    <div className="grid content-start gap-3 sm:grid-cols-2">
      {ENGINES.models.map((model, i) => (
        <div
          key={model.name}
          className={`app-card p-4 ${
            i === ENGINES.models.length - 1 && ENGINES.models.length % 2 === 1
              ? "sm:col-span-2"
              : ""
          }`}
        >
          <div className="flex items-center gap-2">
            <span className={CARD_NAME}>{model.name}</span>
            <span className="dots flex gap-1" aria-hidden>
              {LEVELS.map((level) => (
                <i
                  key={level}
                  className={`h-1 w-1 rounded-full ${level <= model.level ? "on bg-ink" : "bg-line"}`}
                />
              ))}
            </span>
            {model.name === ENGINES.inUse && (
              <span className="ml-auto rounded-full bg-ok-deep/20 px-2.5 py-1 text-[12px] font-semibold text-ok">
                {ENGINES.inUseLabel}
              </span>
            )}
          </div>
          <p className="t-footnote mt-1 tabular-nums">
            {model.size} · {model.quality}
          </p>
          <p className="t-footnote mt-2">{model.info}</p>
        </div>
      ))}
    </div>
  );
}

// One wide panel for the engine with models to show, then one each for Apple's two.
export default function Engines() {
  const lead = ENGINES.cards.find((card) => card.id === ENGINES.leads)!;
  const rest = ENGINES.cards.filter((card) => card !== lead);
  return (
    <div className="mt-12 grid gap-4 md:grid-cols-2">
      <article className="panel grid min-w-0 gap-10 p-7 sm:p-9 md:col-span-2 lg:grid-cols-[minmax(0,5fr)_minmax(0,7fr)] lg:gap-14 lg:p-12">
        <div className="flex min-w-0 flex-col lg:self-center">
          <Head engine={lead} wide />
          <Facts engine={lead} pinned={false} />
        </div>
        <Models />
      </article>
      {rest.map((engine) => (
        <article key={engine.id} className="panel flex min-w-0 flex-col p-7 sm:p-9">
          <Head engine={engine} />
          <Speaking engine={engine} />
          <Facts engine={engine} />
        </article>
      ))}
    </div>
  );
}
