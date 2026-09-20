export type SpeechBurst = {
  speakStart: number;
  speakEnd: number;
  lands: number;
  shown: number;
};

export function tokensShownBy(ms: number, landings: readonly number[]): number {
  let shown = 0;
  while (shown < landings.length && landings[shown] <= ms) shown++;
  return shown;
}

export function speakingAt(ms: number, bursts: readonly SpeechBurst[]): boolean {
  return bursts.some((b) => b.speakStart <= ms && ms < b.speakEnd);
}

export function formatElapsed(totalSeconds: number): string {
  const s = Math.trunc(totalSeconds);
  const hours = Math.trunc(s / 3600);
  const minutes = String(Math.trunc(s / 60) % 60).padStart(2, "0");
  const seconds = String(s % 60).padStart(2, "0");
  return hours > 0 ? `${hours}:${minutes}:${seconds}` : `${minutes}:${seconds}`;
}
