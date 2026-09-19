"use client";

import { useState, type ReactNode } from "react";
import styles from "./Recorder.module.css";

type Props = {
  label: string;
  className: string;
  onTap: () => void;
  children: ReactNode;
};

// Touchable's feedback: the dip lands on the way down and lifts on release,
// cancel or leaving the control.
export default function Press({ label, className, onTap, children }: Props) {
  const [pressed, setPressed] = useState(false);
  return (
    <button
      type="button"
      aria-label={label}
      className={`${styles.circle} ${className}`}
      data-pressed={pressed}
      onPointerDown={() => setPressed(true)}
      onPointerUp={() => setPressed(false)}
      onPointerLeave={() => setPressed(false)}
      onPointerCancel={() => setPressed(false)}
      onClick={onTap}
    >
      {children}
    </button>
  );
}
