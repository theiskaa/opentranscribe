"use client";

import Image from "next/image";
import { useCallback, useEffect, useRef, useState, useSyncExternalStore } from "react";
import { formatElapsed, speakingAt, tokensShownBy } from "@/lib/recorder/schedule";
import { sceneVoiceLevel } from "@/lib/recorder/voice";
import { TAKE, takeText } from "@/lib/recorder/take";
import Controls from "./Controls";
import Glyph from "./Glyph";
import LiveTranscript from "./LiveTranscript";
import StateLine from "./StateLine";
import Timer from "./Timer";
import Waveform, { type WaveformHandle } from "./Waveform";
import { TAKE_PACING, WAVEFORM } from "./tokens";
import styles from "./Recorder.module.css";

type Status = "starting" | "recording" | "paused" | "ending";

const alphaOf = (hex: string) => parseInt(hex.slice(7, 9), 16) / 255;
const BAR = TAKE.colors.waveformBar.slice(0, 7);
const BAR_IDLE = alphaOf(TAKE.colors.waveformBarIdle);
const BASELINE = alphaOf(TAKE.colors.waveformBaseline);
const FADED = alphaOf(TAKE.colors.liveTextFaded);

function useReducedMotion(): boolean {
  return useSyncExternalStore(
    (notify) => {
      const query = window.matchMedia("(prefers-reduced-motion: reduce)");
      query.addEventListener("change", notify);
      return () => query.removeEventListener("change", notify);
    },
    () => window.matchMedia("(prefers-reduced-motion: reduce)").matches,
    () => false,
  );
}

// The app's recorder, playing the take the onboarding plays. Everything on
// the screen derives from one elapsed time, which only runs while the phone is
// in view.
export default function Recorder() {
  const root = useRef<HTMLDivElement>(null);
  const band = useRef<WaveformHandle>(null);
  const clock = useRef({ elapsed: 0, lastFrame: 0, lastSample: 0 });
  const [status, setStatus] = useState<Status>("starting");
  const [visible, setVisible] = useState(false);
  const [takeId, setTakeId] = useState(0);
  const [seconds, setSeconds] = useState(0);
  const [shown, setShown] = useState(0);
  const reduceMotion = useReducedMotion();

  useEffect(() => {
    const el = root.current;
    if (!el) return;
    let onScreen = false;
    const sync = () => setVisible(onScreen && document.visibilityState === "visible");
    const observer = new IntersectionObserver(
      (entries) => {
        onScreen = entries[entries.length - 1].isIntersecting;
        sync();
      },
      { threshold: 0.5 },
    );
    observer.observe(el);
    document.addEventListener("visibilitychange", sync);
    return () => {
      observer.disconnect();
      document.removeEventListener("visibilitychange", sync);
    };
  }, []);

  const restart = useCallback(() => {
    clock.current = { elapsed: 0, lastFrame: 0, lastSample: 0 };
    setSeconds(0);
    setShown(0);
    setTakeId((id) => id + 1);
    setStatus("recording");
  }, []);

  useEffect(() => {
    if (!visible) return;
    if (status === "starting") {
      const timer = setTimeout(() => setStatus("recording"), TAKE_PACING.settleMs);
      return () => clearTimeout(timer);
    }
    if (status === "ending") {
      const timer = setTimeout(restart, TAKE_PACING.endingMs);
      return () => clearTimeout(timer);
    }
  }, [status, visible, restart]);

  useEffect(() => {
    if (!visible || status !== "recording") return;
    const c = clock.current;
    c.lastFrame = 0;
    let raf = requestAnimationFrame(function frame(ts) {
      // A frame that arrives late never makes the take jump to catch up.
      if (c.lastFrame) c.elapsed += Math.min(ts - c.lastFrame, 100);
      c.lastFrame = ts;
      if (c.elapsed >= TAKE.lengthMs) {
        setSeconds(Math.floor(TAKE.lengthMs / 1000));
        setShown(TAKE.tokens.length);
        setStatus("ending");
        return;
      }
      if (c.elapsed - c.lastSample >= WAVEFORM.sampleEveryMs) {
        c.lastSample = c.elapsed;
        band.current?.push(sceneVoiceLevel(c.elapsed, speakingAt(c.elapsed, TAKE.bursts)));
      }
      setSeconds(Math.floor(c.elapsed / 1000));
      setShown(tokensShownBy(c.elapsed, TAKE.landings));
      raf = requestAnimationFrame(frame);
    });
    return () => cancelAnimationFrame(raf);
  }, [visible, status, takeId]);

  const paused = status === "paused";
  const live = status === "recording" || status === "ending";
  const end = () => setStatus((s) => (s === "starting" ? s : "ending"));

  return (
    <figure
      ref={root}
      className={styles.phone}
      aria-label="A recording in progress. The words appear as they are spoken."
    >
      <Image
        src="/shots/recording@2x.png"
        alt=""
        width={692}
        height={1414}
        sizes="(min-width: 1024px) 330px, 70vw"
        className={styles.bezel}
        draggable={false}
        priority
      />
      <div className={styles.stage} style={{ ["--faded" as string]: FADED }}>
        <div className={styles.bar}>
          <div className={styles.barRow}>
            <span className={`${styles.circle} ${styles.barCircle} ${styles.inert}`} aria-hidden>
              <Glyph name="globe" size={20} />
            </span>
          </div>
          <div className={styles.title} aria-hidden>
            <Timer text={formatElapsed(seconds)} paused={paused} reduceMotion={reduceMotion} />
            <StateLine label={paused ? "Paused" : live ? "Recording" : null} />
          </div>
        </div>
        <div className={styles.body}>
          <div className={styles.spaceTop} />
          <Waveform
            key={takeId}
            ref={band}
            active={status === "recording"}
            visible={visible}
            bar={BAR}
            barIdleAlpha={BAR_IDLE}
            baselineAlpha={BASELINE}
          />
          <div className={styles.bandGap} />
          <LiveTranscript text={takeText(shown)} reduceMotion={reduceMotion} />
          <div className={styles.spaceBottom} />
        </div>
        <Controls
          paused={paused}
          onClose={end}
          onRestart={restart}
          onComplete={end}
          onTogglePause={() =>
            setStatus((s) => (s === "paused" ? "recording" : s === "recording" ? "paused" : s))
          }
        />
        <p className={styles.srOnly}>{takeText(TAKE.tokens.length)}</p>
      </div>
    </figure>
  );
}
