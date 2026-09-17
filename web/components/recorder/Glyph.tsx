import { GLYPHS, GLYPH_EM, GLYPH_LINE } from "./glyphs";
import styles from "./Recorder.module.css";

export type GlyphName = keyof typeof GLYPHS;

export default function Glyph({ name, size }: { name: GlyphName; size: number }) {
  const glyph = GLYPHS[name];
  return (
    <svg
      aria-hidden
      className={styles.glyph}
      viewBox={`0 0 ${glyph.advance} ${GLYPH_LINE}`}
      style={{
        width: `calc(${(glyph.advance / GLYPH_EM) * size} * var(--pt))`,
        height: `calc(${(GLYPH_LINE / GLYPH_EM) * size} * var(--pt))`,
      }}
    >
      <path d={glyph.d} />
    </svg>
  );
}
