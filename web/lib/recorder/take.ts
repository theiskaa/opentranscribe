import data from "./take.json";
import type { SpeechBurst } from "./schedule";

export const TAKE = {
  lengthMs: data.lengthMs as number,
  tokens: data.tokens as readonly string[],
  joiner: data.joiner as string,
  bursts: data.bursts as readonly SpeechBurst[],
  landings: data.landings as readonly number[],
  colors: data.colors,
};

export function takeText(shown: number): string {
  return TAKE.tokens.slice(0, shown).join(TAKE.joiner);
}
