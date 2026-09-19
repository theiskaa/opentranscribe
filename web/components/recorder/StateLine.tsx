"use client";

import { useChange } from "./useChange";
import styles from "./Recorder.module.css";

// The word under the clock. Its line is held whether or not there is a word
// in it, and a change crossfades.
export default function StateLine({ label }: { label: string | null }) {
  const { now, gone } = useChange(label);
  return (
    <div className={styles.stateLine}>
      {gone && (
        <span key={`gone-${gone}`} className={styles.stateGone}>
          {gone}
        </span>
      )}
      {now && (
        <span key={now} className={styles.stateWord}>
          {now}
        </span>
      )}
    </div>
  );
}
