"use client";

import { useLayoutEffect, useRef } from "react";
import { LiveWindow } from "./liveWindow";
import styles from "./Recorder.module.css";

export default function LiveTranscript({
  text,
  reduceMotion,
}: {
  text: string;
  reduceMotion: boolean;
}) {
  const block = useRef<HTMLDivElement>(null);
  const live = useRef<LiveWindow | null>(null);

  useLayoutEffect(() => {
    if (!block.current) return;
    const model = new LiveWindow(block.current, {
      window: styles.window,
      line: styles.line,
      word: styles.word,
      wordIn: styles.wordIn,
      wordNew: styles.wordNew,
      wordOld: styles.wordOld,
      measure: styles.measure,
    });
    live.current = model;
    return () => {
      live.current = null;
      model.dispose();
    };
  }, []);

  useLayoutEffect(() => {
    if (!live.current) return;
    live.current.reduceMotion = reduceMotion;
    live.current.setText(text);
  }, [text, reduceMotion]);

  return <div ref={block} className={styles.words} aria-hidden />;
}
