// Flutter's Cubic: the curve's y where its x is [x], found by bisection.
export function cubic(x1: number, y1: number, x2: number, y2: number, x: number): number {
  let lo = 0;
  let hi = 1;
  for (let i = 0; i < 24; i++) {
    const t = (lo + hi) / 2;
    const at = 3 * (1 - t) * (1 - t) * t * x1 + 3 * (1 - t) * t * t * x2 + t * t * t;
    if (at < x) lo = t;
    else hi = t;
  }
  const t = (lo + hi) / 2;
  return 3 * (1 - t) * (1 - t) * t * y1 + 3 * (1 - t) * t * t * y2 + t * t * t;
}

export const easeOut = (x: number) => cubic(0, 0, 0.58, 1, x);
export const easeInOut = (x: number) => cubic(0.42, 0, 0.58, 1, x);
