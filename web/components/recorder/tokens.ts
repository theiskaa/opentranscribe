// The app's own values, in points, named as the app names them.
export const STAGE = { width: 402, columnInset: 40 } as const;

export const WAVEFORM = {
  barWidth: 3,
  gap: 3,
  height: 96,
  fade: 48,
  capacity: 256,
  activityMs: 260,
  minGapMs: 20,
  maxGapMs: 120,
  sampleEveryMs: 50,
} as const;

export const WORDS = {
  lines: 4,
  edgeFade: 0.7,
  lineShiftMs: 250,
  staggerMs: 30,
} as const;

export const ROLL = { staggerMs: 30 } as const;

export const TAKE_PACING = { settleMs: 350, endingMs: 1400 } as const;
