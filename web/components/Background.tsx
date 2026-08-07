"use client";

import { useEffect, useRef } from "react";
import { INK, smooth } from "@/lib/canvas";

// Ports the app's reflection-card dither. Math mirrors lib/view/widgets/dither.dart.
const BAYER = [
  [0, 32, 8, 40, 2, 34, 10, 42],
  [48, 16, 56, 24, 50, 18, 58, 26],
  [12, 44, 4, 36, 14, 46, 6, 38],
  [60, 28, 52, 20, 62, 30, 54, 22],
  [3, 35, 11, 43, 1, 33, 9, 41],
  [51, 19, 59, 27, 49, 17, 57, 25],
  [15, 47, 7, 39, 13, 45, 5, 37],
  [63, 31, 55, 23, 61, 29, 53, 21],
];

const lerp = (a: number, b: number, t: number) => a + (b - a) * t;
const hash = (x: number, y: number) => {
  const s = Math.sin(x * 41.31 + y * 289.17) * 43758.5453;
  return s - Math.floor(s);
};
const noise = (x: number, y: number) => {
  const ix = Math.floor(x);
  const iy = Math.floor(y);
  const fx = smooth(x - ix);
  const fy = smooth(y - iy);
  return lerp(
    lerp(hash(ix, iy), hash(ix + 1, iy), fx),
    lerp(hash(ix, iy + 1), hash(ix + 1, iy + 1), fx),
    fy,
  );
};
const fbm = (x: number, y: number) => {
  let sum = 0;
  let amp = 0.5;
  let px = x;
  let py = y;
  for (let i = 0; i < 3; i++) {
    sum += amp * noise(px, py);
    px = px * 2.03 + 1.7;
    py = py * 2.03 + 9.2;
    amp *= 0.5;
  }
  return sum;
};
const threshold = (c: number, r: number) => lerp(BAYER[r % 8][c % 8] / 64, hash(c, r), 0.06);
const smoothstep = (lo: number, hi: number, v: number) => smooth((v - lo) / (hi - lo));

const CELL = 3;
const OPACITY = 0.16;
const REACH = 0.42;

export default function Background() {
  const ref = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = ref.current;
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    if (!ctx) return;
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    const cell = CELL * dpr;

    const draw = () => {
      const w = Math.floor(canvas.clientWidth * dpr);
      const h = Math.floor(canvas.clientHeight * dpr);
      if (w === 0 || h === 0) return;
      canvas.width = w;
      canvas.height = h;
      ctx.clearRect(0, 0, w, h);
      ctx.fillStyle = INK;
      ctx.globalAlpha = OPACITY;
      const cols = Math.ceil(w / cell);
      const rows = Math.ceil(h / cell);
      for (let row = 0; row < rows; row++) {
        for (let col = 0; col < cols; col++) {
          const x = col * cell;
          const y = row * cell;
          const qx = x / w;
          const qy = y / w;
          const d = Math.hypot(1 - qx, qy);
          const glow = smooth(1 - smoothstep(0.02, REACH, d));
          if (glow <= 0) continue;
          const breathe = 0.82 + 0.34 * (fbm(qx * 2.6, qy * 2.6) - 0.5);
          if (glow * 0.32 * breathe <= threshold(col, row)) continue;
          ctx.fillRect(x, y, cell, cell);
        }
      }
    };

    draw();
    const ro = new ResizeObserver(draw);
    ro.observe(canvas);
    return () => ro.disconnect();
  }, []);

  return (
    <canvas ref={ref} aria-hidden className="pointer-events-none absolute inset-0 z-0 h-full w-full" />
  );
}
