import { SF, SF_LINE } from "./sfGlyphs";

export type SfName = keyof typeof SF;

export default function Sf({ name, className = "" }: { name: SfName; className?: string }) {
  const glyph = SF[name];
  return (
    <svg
      viewBox={`0 0 ${glyph.advance} ${SF_LINE}`}
      className={className}
      fill="currentColor"
      aria-hidden
    >
      <path d={glyph.d} />
    </svg>
  );
}
