"use client";

import { useState, type KeyboardEvent } from "react";
import { ENGINES } from "@/lib/site";
import { AppleIcon, OpenAIIcon } from "./Icons";

const MARKS = { apple: AppleIcon, openai: OpenAIIcon } as const;
const LEVELS = [1, 2, 3, 4, 5] as const;

// Mirrors the app's transcription screen: the switch, then that engine's cards.
export default function Engines() {
  const [active, setActive] = useState(() =>
    ENGINES.cards.findIndex((card) => card.id === ENGINES.opensOn),
  );
  const engine = ENGINES.cards[active];
  const Mark = MARKS[engine.mark];

  const onArrow = (e: KeyboardEvent) => {
    const count = ENGINES.cards.length;
    const step = e.key === "ArrowRight" ? 1 : e.key === "ArrowLeft" ? -1 : 0;
    const edge = e.key === "Home" ? 0 : e.key === "End" ? count - 1 : -1;
    if (step === 0 && edge < 0) return;
    e.preventDefault();
    const next = edge >= 0 ? edge : (active + step + count) % count;
    setActive(next);
    document.getElementById(`engine-tab-${ENGINES.cards[next].id}`)?.focus();
  };

  return (
    <div className="panel mt-12 p-5 sm:p-9">
      <div
        role="tablist"
        aria-label={ENGINES.switchLabel}
        onKeyDown={onArrow}
        className="relative grid grid-cols-3 rounded-full border border-line bg-canvas p-1"
      >
        <span
          aria-hidden
          className="engine-thumb absolute bottom-1 top-1 w-[calc((100%-0.5rem)/3)] rounded-full bg-surface ring-1 ring-line"
          style={{ transform: `translateX(${active * 100}%)`, left: "0.25rem" }}
        />
        {ENGINES.cards.map((card, i) => {
          const TabMark = MARKS[card.mark];
          return (
            <button
              key={card.id}
              role="tab"
              type="button"
              id={`engine-tab-${card.id}`}
              aria-selected={i === active}
              aria-controls="engine-panel"
              tabIndex={i === active ? 0 : -1}
              onClick={() => setActive(i)}
              className={`relative z-10 flex items-center justify-center gap-2 rounded-full px-2 py-2.5 text-[14px] font-semibold tracking-[-0.2px] transition-colors duration-200 sm:text-[15px] ${
                i === active ? "text-ink" : "text-ink-2 hover:text-ink"
              }`}
            >
              <TabMark className="h-[15px] w-[15px] flex-none" />
              {card.tab}
            </button>
          );
        })}
      </div>

      <div
        id="engine-panel"
        role="tabpanel"
        aria-labelledby={`engine-tab-${engine.id}`}
        className="mt-8 grid gap-10 lg:grid-cols-[minmax(0,5fr)_minmax(0,7fr)] lg:gap-14"
      >
        <div>
          <div className="flex items-center gap-4">
            <span className="grid h-12 w-12 flex-none place-items-center rounded-[14px] bg-ink/[0.06] text-ink">
              <Mark className="h-[22px] w-[22px]" />
            </span>
            <div className="min-w-0">
              <h3 className="t-title">{engine.name}</h3>
              <p className="t-footnote text-ink-3">{engine.maker}</p>
            </div>
          </div>
          <p className="t-body mt-6 max-w-[44ch] text-ink-2">{engine.note}</p>
          <dl className="mt-7">
            {engine.facts.map((fact, i) => (
              <div key={ENGINES.labels[i]} className="border-t border-line py-3.5">
                <dt className="t-footnote text-ink-3">{ENGINES.labels[i]}</dt>
                <dd className="t-subhead mt-0.5 text-ink">{fact}</dd>
              </div>
            ))}
          </dl>
        </div>

        {engine.id === "whisper" ? (
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
                  <span className="text-[17px] font-semibold tracking-[-0.4px] text-ink">
                    {model.name}
                  </span>
                  <span className="flex gap-[3px]" aria-hidden>
                    {LEVELS.map((level) => (
                      <i
                        key={level}
                        className={`h-[5px] w-[5px] rounded-full ${level <= model.level ? "bg-ink" : "bg-line"}`}
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
        ) : (
          <div className="content-start">
            <p className="t-eyebrow pl-1">{ENGINES.speaking.label}</p>
            <div className="app-card mt-3 flex items-center gap-4 p-4">
              <span className="text-[30px] leading-none" aria-hidden>
                {ENGINES.speaking.flag}
              </span>
              <div className="min-w-0 flex-1">
                <p className="text-[17px] font-semibold tracking-[-0.4px] text-ink">
                  {ENGINES.speaking.language}
                </p>
                <p className="t-footnote mt-0.5">
                  {ENGINES.speaking.ready} · {engine.name}
                </p>
              </div>
              <span className="text-ink-2" aria-hidden>
                ›
              </span>
            </div>
            <p className="t-eyebrow mt-7 pl-1">{ENGINES.speaking.alsoLabel}</p>
            <div className="mt-3 flex flex-wrap gap-2">
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
        )}
      </div>
    </div>
  );
}
