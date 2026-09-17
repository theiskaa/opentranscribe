"use client";

import { useEffect, useRef } from "react";
import { BAYER_8, INK } from "@/lib/canvas";

const CELL = 4;
const OPACITY = 0.13;
const STRETCH = 1.25;
const FALLOFF = 2.1;

// Mirrors the halo on the app's club sheet.
export default function DitherCorner({ className = "" }: { className?: string }) {
  const ref = useRef<HTMLCanvasElement>(null);

  useEffect(() => {
    const canvas = ref.current;
    if (!canvas) return;
    const draw = () => {
      const { width, height } = canvas.getBoundingClientRect();
      const dpr = window.devicePixelRatio || 1;
      const cols = Math.ceil(width / CELL);
      const rows = Math.ceil(height / CELL);
      canvas.width = Math.round(width * dpr);
      canvas.height = Math.round(height * dpr);
      const ctx = canvas.getContext("2d");
      if (!ctx || cols === 0 || rows === 0) return;
      ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      ctx.globalAlpha = OPACITY;
      ctx.fillStyle = INK;
      for (let y = 0; y < rows; y++) {
        for (let x = 0; x < cols; x++) {
          const dx = 1 - x / cols;
          const dy = y / rows;
          const level = Math.max(0, 1 - Math.hypot(dx, dy * STRETCH)) ** FALLOFF;
          if (level > (BAYER_8[y & 7][x & 7] + 0.5) / 64) {
            ctx.fillRect(x * CELL, y * CELL, CELL - 1, CELL - 1);
          }
        }
      }
    };
    const observer = new ResizeObserver(draw);
    observer.observe(canvas);
    return () => observer.disconnect();
  }, []);

  return <canvas ref={ref} aria-hidden className={className} />;
}
