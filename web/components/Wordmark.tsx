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

export function Wordmark({ className = "" }: { className?: string }) {
  return (
    <span className={`inline-flex items-center gap-3 ${className}`}>
      <WaveMark className="h-[0.8em] w-auto" />
      <span className="font-semibold tracking-tight">OpenTranscribe</span>
    </span>
  );
}
