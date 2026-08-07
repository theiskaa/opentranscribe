import { WAVE_PATHS, WAVE_VIEWBOX } from "@/lib/wave";

export function WaveMark({ className = "" }: { className?: string }) {
  return (
    <svg viewBox={WAVE_VIEWBOX} className={className} fill="currentColor" aria-hidden>
      {WAVE_PATHS.map((d) => (
        <path key={d} d={d} />
      ))}
    </svg>
  );
}
