"use client";

import { forwardRef, useEffect, useImperativeHandle, useRef } from "react";
import { INK, clamp01, smooth } from "@/lib/canvas";

// Ports the app's reflection-scrubber ink-bridge. Math mirrors
// reflection_page_logic.dart. Driven 1:1 by scroll, so it is NOT gated on
// reduced motion (the flow is the scroll, like the app).
const DOT = 7;
const GAP = 22;
const ACTIVE = 1.4;
const WAIST = 0.6;
const STRETCH = 0.25;
const ATTACH = 0.8;
const PITCH = DOT + GAP;
const TRACK_OPACITY = 0.16;

const drain = (t: number) => 1 - smooth((clamp01(t) - 0.08) / 0.84);
const fill = (t: number) => {
  const x = clamp01((clamp01(t) - 0.08) / 0.92);
  if (x <= 0) return 0;
  const c = 1.2;
  const u = x - 1;
  return 1 + (c + 1) * u * u * u + c * u * u;
};
const neck = (t: number) => Math.sin(Math.PI * clamp01(t));

export interface LiquidDotsHandle {
  setPosition(p: number): void;
}

const LiquidDots = forwardRef<LiquidDotsHandle, { count: number }>(function LiquidDots(
  { count },
  ref,
) {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const posRef = useRef(0);
  const drawRef = useRef<() => void>(() => {});

  useEffect(() => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    const w = 18;
    const h = count * PITCH;
    canvas.width = w * dpr;
    canvas.height = h * dpr;
    canvas.style.width = `${w}px`;
    canvas.style.height = `${h}px`;
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);

    const restR = DOT / 2;
    const inkR = restR * ACTIVE;
    const cx = w / 2;
    const centerOf = (i: number) => i * PITCH + PITCH / 2;

    const draw = () => {
      ctx.clearRect(0, 0, w, h);
      ctx.fillStyle = INK;
      ctx.globalAlpha = TRACK_OPACITY;
      for (let i = 0; i < count; i++) {
        ctx.beginPath();
        ctx.arc(cx, centerOf(i), restR, 0, Math.PI * 2);
        ctx.fill();
      }

      ctx.globalAlpha = 1;
      const p = Math.min(Math.max(posRef.current, 0), count - 1);
      const source = Math.floor(p);
      const t = p - source;
      const nk = neck(t);
      const sy = centerOf(source);
      const rs = inkR * drain(t);

      const blob = (y: number, r: number) => {
        if (r <= 0) return;
        const e = 1 + STRETCH * nk;
        ctx.beginPath();
        ctx.ellipse(cx, y, r / e, r * e, 0, 0, Math.PI * 2);
        ctx.fill();
      };

      blob(sy, rs);
      if (t > 0 && source + 1 < count) {
        const dy = centerOf(source + 1);
        const rd = inkR * fill(t);
        blob(dy, rd);
        const waist = Math.min(rs, rd) * WAIST * nk;
        if (waist > 0) {
          const mid = (sy + dy) / 2;
          ctx.beginPath();
          ctx.moveTo(cx - rs * ATTACH, sy);
          ctx.quadraticCurveTo(cx - waist, mid, cx - rd * ATTACH, dy);
          ctx.lineTo(cx + rd * ATTACH, dy);
          ctx.quadraticCurveTo(cx + waist, mid, cx + rs * ATTACH, sy);
          ctx.closePath();
          ctx.fill();
        }
      }
    };

    drawRef.current = draw;
    draw();
  }, [count]);

  useImperativeHandle(
    ref,
    () => ({
      setPosition(p: number) {
        posRef.current = p;
        drawRef.current();
      },
    }),
    [],
  );

  return <canvas ref={canvasRef} aria-hidden className="block" />;
});

export default LiquidDots;
