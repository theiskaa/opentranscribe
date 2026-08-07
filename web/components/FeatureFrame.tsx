"use client";

import Image from "next/image";
import { useEffect, useRef, useState } from "react";
import { FEATURES, SHOT_RATIO } from "@/lib/site";
import { clamp } from "@/lib/canvas";
import LiquidDots, { type LiquidDotsHandle } from "./LiquidDots";

const STEP_VH = 80;
const N = FEATURES.length;

export default function FeatureFrame() {
  const track = useRef<HTMLDivElement>(null);
  const dots = useRef<LiquidDotsHandle>(null);
  const [active, setActive] = useState(0);

  useEffect(() => {
    let raf = 0;
    const update = () => {
      raf = 0;
      const el = track.current;
      if (!el) return;
      const r = el.getBoundingClientRect();
      const span = r.height - window.innerHeight;
      const p = span > 0 ? clamp(-r.top / span, 0, 1) : 0;
      const pos = clamp(p * N - 0.5, 0, N - 1);
      dots.current?.setPosition(pos);
      const next = Math.round(pos);
      setActive((cur) => (cur === next ? cur : next));
    };
    const onScroll = () => {
      if (!raf) raf = requestAnimationFrame(update);
    };
    update();
    window.addEventListener("scroll", onScroll, { passive: true });
    window.addEventListener("resize", onScroll, { passive: true });
    return () => {
      window.removeEventListener("scroll", onScroll);
      window.removeEventListener("resize", onScroll);
      if (raf) cancelAnimationFrame(raf);
    };
  }, []);

  return (
    <div ref={track} className="relative" style={{ height: `${FEATURES.length * STEP_VH}vh` }}>
      {FEATURES.map((f, i) => (
        <div
          key={f.id}
          id={f.id}
          aria-hidden
          className="absolute left-0 h-px w-px"
          style={{ top: `${i * STEP_VH}vh` }}
        />
      ))}

      <div className="sticky top-0 h-svh transform-gpu overflow-hidden lg:flex lg:items-center">
        <div className="mx-auto flex h-full w-full max-w-frame flex-col px-6 pt-24 sm:px-12 lg:grid lg:h-auto lg:grid-cols-12 lg:items-center lg:gap-10 lg:pt-0">
          <div className="flex items-center gap-9 lg:col-span-6">
            <div className="relative hidden flex-none self-center sm:block">
              <LiquidDots ref={dots} count={FEATURES.length} />
              <div className="absolute inset-0 flex flex-col">
                {FEATURES.map((f) => (
                  <a
                    key={f.id}
                    href={`#${f.id}`}
                    aria-label={f.label}
                    className="flex-1"
                  />
                ))}
              </div>
            </div>
            <div className="grid min-w-0 flex-1">
              {FEATURES.map((f, i) => {
                const on = active === i;
                return (
                  <div
                    key={f.id}
                    aria-hidden={on ? undefined : true}
                    className={`[grid-area:1/1] transition-opacity duration-500 ease-out ${
                      on ? "opacity-100" : "pointer-events-none opacity-0"
                    }`}
                  >
                    <p className="t-eyebrow">
                      {f.n} / {f.label}
                    </p>
                    <h2 className="t-display mt-6">{f.title}</h2>
                    <p className="t-body mt-6 max-w-prose text-ink-2">{f.body}</p>
                    <p className="t-footnote mt-8 max-w-prose">{f.foot}</p>
                  </div>
                );
              })}
            </div>
          </div>

          <div className="mt-8 min-h-0 flex-1 lg:col-span-5 lg:col-start-8 lg:mt-0 lg:min-h-fit lg:flex-none">
            <div
              style={{ aspectRatio: SHOT_RATIO }}
              className="relative mx-auto h-full [mask-image:linear-gradient(to_bottom,black_84%,transparent)] lg:ml-auto lg:mr-0 lg:h-auto lg:w-full lg:max-w-[312px]"
            >
              {FEATURES.map((f, i) => (
                <Image
                  key={f.shot}
                  src={f.shot}
                  alt={f.cap}
                  aria-hidden={active === i ? undefined : true}
                  fill
                  sizes="312px"
                  className={`select-none object-cover object-top transition-opacity duration-500 ease-out ${
                    active === i ? "opacity-100" : "opacity-0"
                  }`}
                  draggable={false}
                />
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
