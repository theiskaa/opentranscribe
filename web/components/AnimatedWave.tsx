"use client";

import { useEffect, useRef } from "react";

const PATTERN = [0.35, 0.65, 1.0, 0.7, 0.5, 0.85, 0.4];
const SWELL_DEPTH = 0.5;
const SWELL_LAG = 0.8;
const PERIOD_MS = 1000;

const BAR_W = 42;
const PITCH = 75;
const VB_H = 481;
const MID = VB_H / 2;

function swell(i: number, phase: number) {
  const wave = 0.5 + 0.5 * Math.sin(phase - i * SWELL_LAG);
  return 1 - SWELL_DEPTH * (1 - wave);
}

export function AnimatedWave({ className = "" }: { className?: string }) {
  const bars = useRef<(SVGRectElement | null)[]>([]);

  useEffect(() => {
    const apply = (phase: number, intro: number) => {
      for (let i = 0; i < PATTERN.length; i++) {
        const el = bars.current[i];
        if (!el) continue;
        const h = Math.max(BAR_W, VB_H * PATTERN[i] * swell(i, phase) * intro);
        el.setAttribute("y", String(MID - h / 2));
        el.setAttribute("height", String(h));
      }
    };

    if (window.matchMedia("(prefers-reduced-motion: reduce)").matches) return;

    const INTRO_MS = 450;
    let start = -1;
    let raf = 0;
    const loop = (now: number) => {
      if (start < 0) start = now;
      const p = Math.min(1, (now - start) / INTRO_MS);
      const intro = 0.12 + 0.88 * (1 - Math.pow(1 - p, 3));
      apply((now / PERIOD_MS) * 2 * Math.PI, intro);
      raf = requestAnimationFrame(loop);
    };
    raf = requestAnimationFrame(loop);
    return () => cancelAnimationFrame(raf);
  }, []);

  return (
    <svg viewBox="0 0 492 481" className={className} fill="currentColor" aria-hidden>
      {PATTERN.map((h, i) => (
        <rect
          key={i}
          ref={(el) => {
            bars.current[i] = el;
          }}
          x={i * PITCH}
          width={BAR_W}
          rx={BAR_W / 2}
          y={MID - (VB_H * h) / 2}
          height={VB_H * h}
        />
      ))}
    </svg>
  );
}
