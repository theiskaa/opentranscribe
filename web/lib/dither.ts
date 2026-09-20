import { BAYER_8 } from "./canvas";

// The app's dither maths (lib/view/widgets/dither.dart), function for function.
const lerp = (a: number, b: number, t: number) => a + (b - a) * t;
const smooth = (t: number) => t * t * (3 - 2 * t);

function hash(x: number, y: number): number {
  const s = Math.sin(x * 41.31 + y * 289.17) * 43758.5453;
  return s - Math.floor(s);
}

export function ditherThreshold(col: number, row: number): number {
  return lerp(BAYER_8[row & 7][col & 7] / 64, hash(col, row), 0.06);
}

function noise(x: number, y: number): number {
  const ix = Math.floor(x);
  const iy = Math.floor(y);
  const fx = smooth(x - ix);
  const fy = smooth(y - iy);
  return lerp(
    lerp(hash(ix, iy), hash(ix + 1, iy), fx),
    lerp(hash(ix, iy + 1), hash(ix + 1, iy + 1), fx),
    fy,
  );
}

export function ditherFbm(x: number, y: number): number {
  let sum = 0;
  let amp = 0.5;
  let px = x;
  let py = y;
  for (let i = 0; i < 3; i++) {
    sum += amp * noise(px, py);
    px = px * 2.03 + 1.7;
    py = py * 2.03 + 9.2;
    amp *= 0.5;
  }
  return sum;
}

export function ditherSmoothstep(lo: number, hi: number, v: number): number {
  return smooth(Math.min(1, Math.max(0, (v - lo) / (hi - lo))));
}
