"use client";

import Image from "next/image";
import { useEffect, useRef, useState } from "react";
import { STEPS, SHOT_W, SHOT_H } from "@/lib/site";
import Reveal from "./Reveal";

export default function HowItWorks() {
  const [active, setActive] = useState(0);
  const rows = useRef<(HTMLDivElement | null)[]>([]);

  useEffect(() => {
    const io = new IntersectionObserver(
      (entries) => {
        for (const e of entries) {
          if (e.isIntersecting) {
            const i = rows.current.indexOf(e.target as HTMLDivElement);
            if (i >= 0) setActive(i);
          }
        }
      },
      { rootMargin: "-45% 0px -45% 0px", threshold: 0 },
    );
    rows.current.forEach((r) => r && io.observe(r));
    return () => io.disconnect();
  }, []);

  return (
    <div className="grid gap-12 lg:grid-cols-12 lg:gap-10">
      <Reveal stagger className="lg:col-span-7">
        {STEPS.map((s, i) => {
          const on = active === i;
          return (
            <div
              key={s.n}
              ref={(el) => {
                rows.current[i] = el;
              }}
              className="relative border-t border-line py-8 pl-6 first:border-t-0 first:pt-0"
            >
              <span
                aria-hidden
                className={`absolute left-0 top-0 h-full w-px transition-colors duration-500 ${
                  on ? "bg-ink" : "bg-line"
                }`}
              />
              <p
                className={`t-eyebrow mb-3 transition-colors duration-300 ${
                  on ? "text-ink" : "text-ink-faint"
                }`}
              >
                {s.n}
              </p>
              <h3
                className={`t-h2 transition-colors duration-300 ${
                  on ? "text-ink" : "text-ink-muted"
                }`}
              >
                {s.title}
              </h3>
              <p className="t-body-s mt-3 max-w-prose">{s.body}</p>
            </div>
          );
        })}
      </Reveal>

      <div className="hidden lg:col-span-5 lg:block">
        <div className="sticky top-28">
          <div
            style={{ aspectRatio: `${SHOT_W} / ${SHOT_H}` }}
            className="relative mx-auto w-full max-w-[268px]"
          >
            {STEPS.map((s, i) => (
              <Image
                key={s.shot + i}
                src={s.shot}
                alt={s.title}
                aria-hidden={active === i ? undefined : true}
                width={SHOT_W}
                height={SHOT_H}
                sizes="268px"
                className={`absolute inset-0 h-full w-full object-contain transition-all duration-[600ms] ease-out [filter:drop-shadow(0_30px_60px_rgba(0,0,0,0.6))] ${
                  active === i
                    ? "opacity-100 translate-y-0 scale-100"
                    : "opacity-0 translate-y-3 scale-[0.985]"
                }`}
              />
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
