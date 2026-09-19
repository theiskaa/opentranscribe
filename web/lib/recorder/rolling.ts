type RollingSlot = { char: string; rolls: boolean };

const segmenter = new Intl.Segmenter(undefined, { granularity: "grapheme" });

function graphemes(text: string): string[] {
  return Array.from(segmenter.segment(text), (s) => s.segment);
}

export function rollingSlots(from: string, to: string): RollingSlot[] {
  const a = graphemes(from);
  const b = graphemes(to);
  const length = Math.max(a.length, b.length);
  const slots: RollingSlot[] = [];
  for (let i = 0; i < length; i++) {
    slots.push({ char: b[i] ?? "", rolls: (a[i] ?? "") !== (b[i] ?? "") });
  }
  return slots;
}
