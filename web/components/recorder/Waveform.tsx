"use client";

import { forwardRef, useEffect, useImperativeHandle, useRef } from "react";
import { easeOut } from "@/lib/recorder/curves";
import { waveformLevel } from "@/lib/recorder/level";
import { STAGE, WAVEFORM } from "./tokens";
import styles from "./Recorder.module.css";

export type WaveformHandle = { push: (level: number) => void };

type Props = {
  active: boolean;
  // Whether anyone can see the band; off screen its loop rests.
  visible: boolean;
  bar: string;
  barIdleAlpha: number;
  baselineAlpha: number;
};

// A canvas port of the app's band: full of silence from the first frame,
// newest bar at the right edge, one step left per sample with the offset
// interpolated between samples, both ends fading.
const Waveform = forwardRef<WaveformHandle, Props>(function Waveform(
  { active, visible, bar, barIdleAlpha, baselineAlpha },
  ref,
) {
  const canvas = useRef<HTMLCanvasElement>(null);
  const state = useRef({
    samples: new Array<number>(WAVEFORM.capacity).fill(0),
    ticking: active,
    lastFrame: 0,
    now: 0,
    lastSampleAt: 0,
    sampleGap: WAVEFORM.sampleEveryMs as number,
    fraction: 0,
    activity: active ? 1 : 0,
    activityFrom: active ? 1 : 0,
    activityTo: active ? 1 : 0,
    activityStart: 0,
    active,
    visible,
    raf: 0,
    paint: () => {},
    wake: () => {},
  });

  useImperativeHandle(ref, () => ({
    push(level: number) {
      const s = state.current;
      const now = s.ticking ? s.now : 0;
      if (s.lastSampleAt !== 0 && now > s.lastSampleAt) {
        const blended = s.sampleGap * 0.7 + (now - s.lastSampleAt) * 0.3;
        s.sampleGap = Math.min(WAVEFORM.maxGapMs, Math.max(WAVEFORM.minGapMs, blended));
      }
      s.lastSampleAt = now;
      s.fraction = 0;
      s.samples.push(waveformLevel(level));
      if (s.samples.length > WAVEFORM.capacity) s.samples.shift();
      if (!s.ticking) s.paint();
    },
  }));

  useEffect(() => {
    const el = canvas.current;
    if (!el) return;
    const ctx = el.getContext("2d");
    if (!ctx) return;
    const s = state.current;

    const scrollFraction = () => {
      if (s.lastSampleAt === 0) return s.fraction;
      const since = s.now - s.lastSampleAt;
      if (since < 0 || s.sampleGap <= 0) return s.fraction;
      return (s.fraction = Math.min(1, Math.max(0, since / s.sampleGap)));
    };

    s.paint = () => {
      const rect = el.getBoundingClientRect();
      if (rect.width === 0) return;
      const pt = rect.width / (STAGE.width - STAGE.columnInset * 2);
      const dpr = window.devicePixelRatio || 1;
      const w = Math.round(rect.width * dpr);
      const h = Math.round(rect.height * dpr);
      if (el.width !== w || el.height !== h) {
        el.width = w;
        el.height = h;
      }
      ctx.setTransform(pt * dpr, 0, 0, pt * dpr, 0, 0);
      const width = rect.width / pt;
      const height = rect.height / pt;
      ctx.clearRect(0, 0, width, height);

      const { barWidth, gap, fade } = WAVEFORM;
      const step = barWidth + gap;
      const capacity = Math.floor(width / step);
      if (capacity <= 0) return;
      const mid = height / 2;
      const live = s.activity;
      const edge = (x: number) => easeOut(Math.min(1, Math.max(0, Math.min(x, width - x) / fade)));

      if (live > 0.01) {
        const stop = Math.min(0.5, Math.max(0, fade / width));
        const spine = ctx.createLinearGradient(0, mid, width, mid);
        const ink = (a: number) => withAlpha(bar, a);
        spine.addColorStop(0, ink(0));
        spine.addColorStop(stop, ink(baselineAlpha * live));
        spine.addColorStop(1 - stop, ink(baselineAlpha * live));
        spine.addColorStop(1, ink(0));
        ctx.globalAlpha = 1;
        ctx.strokeStyle = spine;
        ctx.lineWidth = 1;
        ctx.lineCap = "butt";
        ctx.beginPath();
        ctx.moveTo(0, mid);
        ctx.lineTo(width, mid);
        ctx.stroke();
      }

      const visibleBars = Math.min(s.samples.length, capacity);
      const shift = scrollFraction() * step;
      const barAlpha = barIdleAlpha + (1 - barIdleAlpha) * live;
      ctx.strokeStyle = bar;
      ctx.lineWidth = barWidth;
      ctx.lineCap = "round";
      for (let i = 0; i < visibleBars; i++) {
        const sample = s.samples[s.samples.length - visibleBars + i];
        const x = width - (visibleBars - i) * step - shift + step;
        if (x < 0 || x > width) continue;
        ctx.globalAlpha = barAlpha * edge(x);
        const half = Math.max(barWidth / 2, sample * mid);
        ctx.beginPath();
        ctx.moveTo(x, mid - half);
        ctx.lineTo(x, mid + half);
        ctx.stroke();
      }
    };

    const frame = (ts: number) => {
      s.raf = 0;
      // Clamped like the take's clock, so time off screen never reads as a gap.
      if (s.ticking && s.lastFrame) s.now += Math.min(ts - s.lastFrame, 100);
      s.lastFrame = ts;
      if (s.activity !== s.activityTo) {
        if (s.activityStart === 0) s.activityStart = ts;
        // A fade turned round mid-way only travels back what it had covered.
        const span = WAVEFORM.activityMs * Math.abs(s.activityTo - s.activityFrom);
        const t = span > 0 ? Math.min(1, (ts - s.activityStart) / span) : 1;
        s.activity = s.activityFrom + (s.activityTo - s.activityFrom) * t;
        // The ticker runs on through the fade, so the band coasts into its
        // last step instead of stopping dead.
        if (t === 1 && !s.active) s.ticking = false;
      }
      s.paint();
      if (s.visible && (s.ticking || s.activity !== s.activityTo)) {
        s.raf = requestAnimationFrame(frame);
      } else {
        s.lastFrame = 0;
      }
    };
    s.wake = () => {
      if (!s.raf && s.visible) s.raf = requestAnimationFrame(frame);
    };

    const resize = new ResizeObserver(() => s.paint());
    resize.observe(el);
    s.paint();
    s.wake();
    return () => {
      resize.disconnect();
      cancelAnimationFrame(s.raf);
      s.raf = 0;
      s.lastFrame = 0;
    };
  }, [bar, barIdleAlpha, baselineAlpha]);

  useEffect(() => {
    const s = state.current;
    s.visible = visible;
    if (s.active !== active) {
      s.active = active;
      s.activityFrom = s.activity;
      s.activityTo = active ? 1 : 0;
      s.activityStart = 0;
      if (active && !s.ticking) {
        // A stopped ticker restarts its clock at zero; the math heals on the
        // first fresh sample.
        s.ticking = true;
        s.now = 0;
      }
    }
    s.wake();
  }, [active, visible]);

  return <canvas ref={canvas} className={styles.band} aria-hidden />;
});

function withAlpha(hex: string, alpha: number): string {
  const n = parseInt(hex.slice(1, 7), 16);
  return `rgb(${(n >> 16) & 255} ${(n >> 8) & 255} ${n & 255} / ${alpha})`;
}

export default Waveform;
