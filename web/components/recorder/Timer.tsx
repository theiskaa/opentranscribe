"use client";

import { rollingSlots } from "@/lib/recorder/rolling";
import { ROLL } from "./tokens";
import { useChange } from "./useChange";
import styles from "./Recorder.module.css";

type Props = { text: string; paused: boolean; reduceMotion: boolean };

// RollingText for the clock: only a digit that changed moves, the old glyph
// and the new one travelling through the line box as one column.
export default function Timer({ text, paused, reduceMotion }: Props) {
  const { now: to, gone } = useChange(text);
  const from = gone ?? to;
  const up = to >= from;
  const old = Array.from(from);
  let rolling = 0;

  return (
    <div className={`${styles.timer} ${paused ? styles.timerPaused : ""}`}>
      {rollingSlots(reduceMotion ? to : from, to).map((slot, i) => {
        if (!slot.rolls) return <span key={i}>{slot.char}</span>;
        const glyphs = up ? [old[i] ?? "", slot.char] : [slot.char, old[i] ?? ""];
        return (
          <span key={i} className={styles.slot}>
            <span
              key={`${from}>${to}`}
              className={`${styles.column} ${up ? styles.rollUp : styles.rollDown}`}
              style={{ animationDelay: `${rolling++ * ROLL.staggerMs}ms` }}
            >
              <span>{glyphs[0]}</span>
              <span>{glyphs[1]}</span>
            </span>
          </span>
        );
      })}
    </div>
  );
}
