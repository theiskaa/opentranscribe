const FLOOR = 0.2;
const CEILING = 0.85;

export function waveformLevel(raw: number): number {
  const windowed = Math.min(1, Math.max(0, (raw - FLOOR) / (CEILING - FLOOR)));
  return Math.pow(windowed, 0.75);
}
