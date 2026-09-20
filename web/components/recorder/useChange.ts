import { useState } from "react";

// The value now and the one it replaced, for a crossfade or a roll.
export function useChange<T>(value: T): { now: T; gone: T | null } {
  const [pair, setPair] = useState<{ now: T; gone: T | null }>({
    now: value,
    gone: null,
  });
  if (pair.now === value) return pair;
  const next = { now: value, gone: pair.now };
  setPair(next);
  return next;
}
