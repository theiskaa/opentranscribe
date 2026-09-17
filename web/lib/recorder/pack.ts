const CJK_RANGE =
  "\\u3000-\\u30ff\\u3400-\\u4dbf\\u4e00-\\u9fff\\uf900-\\ufaff\\uff00-\\uffef";
const CJK_CLOSING = "\\u3001\\u3002\\uff01\\uff0c\\uff1a\\uff1b\\uff1f\\u300d\\u300f\\uff09";
const WORD = new RegExp(`[${CJK_RANGE}][${CJK_CLOSING}]*|[^\\s${CJK_RANGE}]+`, "g");

export type Words = { words: string[]; glued: boolean[] };
type WidthOf = (word: string) => number;
type PackOptions = {
  spaceWidth: number;
  maxWidth: number;
  glued?: readonly boolean[];
};

export function transcriptWords(text: string): Words {
  const words: string[] = [];
  const glued: boolean[] = [];
  let lastEnd: number | null = null;
  for (const match of text.matchAll(WORD)) {
    words.push(match[0]);
    glued.push(lastEnd === match.index);
    lastEnd = match.index + match[0].length;
  }
  return { words, glued };
}

export function packLines(
  words: readonly string[],
  widthOf: WidthOf,
  { spaceWidth, maxWidth, glued, first = 0 }: PackOptions & { first?: number },
): number[][] {
  const lines: number[][] = [];
  let current: number[] = [];
  let used = 0;
  for (let i = first; i < words.length; i++) {
    const width = widthOf(words[i]);
    const joined = current.length === 0 || (glued?.[i] ?? false);
    const advance = joined ? width : spaceWidth + width;
    if (current.length > 0 && used + advance > maxWidth) {
      lines.push(current);
      current = [i];
      used = width;
    } else {
      current.push(i);
      used += advance;
    }
  }
  if (current.length > 0) lines.push(current);
  return lines;
}

export function firstDivergence(
  a: readonly string[],
  b: readonly string[],
  aGlued?: readonly boolean[],
  bGlued?: readonly boolean[],
): number {
  const shared = Math.min(a.length, b.length);
  let i = 0;
  while (i < shared && a[i] === b[i] && (aGlued?.[i] ?? false) === (bGlued?.[i] ?? false)) i++;
  return i;
}

function repackFrom(
  lines: readonly number[][],
  from: number,
  words: readonly string[],
  widthOf: WidthOf,
  options: PackOptions,
): number[][] {
  let keep = 0;
  // A line's break was decided by the word after it, so it is settled only
  // while that word is unchanged.
  while (keep < lines.length && lines[keep][lines[keep].length - 1] < from - 1) keep++;
  const first = keep === 0 ? 0 : lines[keep - 1][lines[keep - 1].length - 1] + 1;
  return [...lines.slice(0, keep), ...packLines(words, widthOf, { ...options, first })];
}

export function packIncrementally(
  words: readonly string[],
  widthOf: WidthOf,
  options: PackOptions & {
    previousWords: readonly string[];
    previous: number[][];
    previousMaxWidth: number | null;
    previousGlued?: readonly boolean[];
  },
): number[][] {
  const { previousWords, previous, previousMaxWidth, previousGlued, ...pack } = options;
  if (pack.maxWidth !== previousMaxWidth) return packLines(words, widthOf, pack);
  const from = firstDivergence(previousWords, words, previousGlued, pack.glued);
  if (from === words.length && from === previousWords.length) return previous;
  return repackFrom(previous, from, words, widthOf, pack);
}
