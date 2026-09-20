export function sceneVoiceLevel(ms: number, speaking: boolean): number {
  const t = ms / 1000;
  const jitter = Math.sin(t * 91.7) * 0.06;
  if (!speaking) return 0.08 + Math.abs(jitter);
  const syllable = Math.pow(Math.sin(t * 2 * Math.PI * 4.3), 2);
  const word = 0.55 + 0.45 * Math.pow(Math.sin(t * 2 * Math.PI * 1.1 + 0.4), 2);
  return Math.min(1, Math.max(0, 0.24 + 0.6 * syllable * word + jitter));
}
