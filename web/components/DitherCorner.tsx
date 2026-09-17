"use client";

import { useEffect, useRef } from "react";
import { INK } from "@/lib/canvas";
import { ditherFbm, ditherSmoothstep, ditherThreshold } from "@/lib/dither";

const CELL = 4;
// The app's clock: a new frame every 0.09 s, the field drifting at 0.02 of it.
const STEP_MS = 90;
const DRIFT = 0.02;

const FIELDS = {
  // The club sheet's halo, anchored to its corner.
  topRight: { opacity: 0.13, tone: 0.4, reach: 0.95 },
  // The hero's: quieter, and reaching down toward the middle of the screen.
  top: { opacity: 0.09, tone: 0.34, reach: 0.78 },
} as const;

type Props = { className?: string; from?: keyof typeof FIELDS };

// The app's DitherField: an ordered dither under a slow breathing noise.
export default function DitherCorner({ className = "", from = "topRight" }: Props) {
  const ref = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = ref.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;
    const field = FIELDS[from];
    let seconds = 0;
    let last = 0;
    let drawnAt = -Infinity;
    let raf = 0;
    let onScreen = false;

    const draw = () => {
      const { width, height } = canvas.getBoundingClientRect();
      if (width === 0 || height === 0) return;
      const dpr = window.devicePixelRatio || 1;
      const w = Math.round(width * dpr);
      const h = Math.round(height * dpr);
      if (canvas.width !== w || canvas.height !== h) {
        canvas.width = w;
        canvas.height = h;
      }
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      ctx.clearRect(0, 0, width, height);
      ctx.globalAlpha = field.opacity;
      ctx.fillStyle = INK;
      const t = seconds * DRIFT;
      const cols = Math.ceil(width / CELL);
      const rows = Math.ceil(height / CELL);
      for (let row = 0; row < rows; row++) {
        for (let col = 0; col < cols; col++) {
          const qx = (col * CELL) / width;
          const qy = (row * CELL) / width;
          // From the top the field is measured against the height it has to
          // fill, so it reaches the same depth at any width.
          const d =
            from === "top"
              ? Math.hypot((qx - 0.5) * 1.15, (row * CELL) / height)
              : Math.hypot(1 - qx, qy);
          const glow = ditherSmoothstep(0, 1, 1 - ditherSmoothstep(0.05, field.reach, d));
          if (glow <= 0) continue;
          const breathe = 0.82 + 0.34 * (ditherFbm(qx * 2.6 + t, qy * 2.6 - t * 0.6) - 0.5);
          if (glow * field.tone * breathe <= ditherThreshold(col, row)) continue;
          ctx.fillRect(col * CELL, row * CELL, CELL - 1, CELL - 1);
        }
      }
    };

    const frame = (ts: number) => {
      raf = 0;
      if (last) seconds += Math.min(ts - last, 100) / 1000;
      last = ts;
      if (ts - drawnAt >= STEP_MS) {
        drawnAt = ts;
        draw();
      }
      wake();
    };
    const wake = () => {
      if (!raf && onScreen && document.visibilityState === "visible") {
        raf = requestAnimationFrame(frame);
      } else if (!onScreen) {
        last = 0;
      }
    };

    const resize = new ResizeObserver(draw);
    resize.observe(canvas);
    const seen = new IntersectionObserver((entries) => {
      onScreen = entries[entries.length - 1].isIntersecting;
      wake();
    });
    seen.observe(canvas);
    const onVisibility = () => {
      last = 0;
      wake();
    };
    document.addEventListener("visibilitychange", onVisibility);
    return () => {
      resize.disconnect();
      seen.disconnect();
      document.removeEventListener("visibilitychange", onVisibility);
      cancelAnimationFrame(raf);
    };
  }, [from]);

  return <canvas ref={ref} aria-hidden className={className} />;
}
