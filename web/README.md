# opentranscribe web

The landing page for opentranscribe. A single dark page: a hero over an
ordered-dither shader, a screenshot fan, and two numbered sections. Next.js,
Tailwind, TypeScript. Nothing here talks to a network at runtime.

```sh
pnpm install
pnpm dev        # http://localhost:3000
pnpm build
pnpm lint
```

## Where things live

- `app/page.tsx`: the page. Hero with the screenshot fan, then `#works`
  (how a recording becomes an entry) and `#privacy` (what the code enforces).
- `lib/site.ts`: links, shared copy, and section data. The hero badge, section
  headings, and privacy prose live in `app/page.tsx` where they are rendered.
- `lib/wave.ts`: the waveform mark's path data, shared by the wordmark and the
  OG image.
- `app/globals.css`: the grayscale tokens, type scale (`t-h1`, `t-eyebrow`,
  `t-mono`, ...), and the shared reveal/motion classes.
- `components/`
  - `Background.tsx`: the WebGL hero backdrop, an 8x8 Bayer ordered-dither
    halo behind the title that fades to black at the edges.
  - `AnimatedWave.tsx`: the waveform mark, animated like the app's swell.
  - `Screenshots.tsx`: the fan of device shots with the hover pop.
  - `HowItWorks.tsx`: the sticky device that swaps screen per step.
  - `Reveal.tsx`: the IntersectionObserver reveal used by the content
    sections; the fan in `Screenshots.tsx` runs its own enter observer.
  - `Nav.tsx`, `Footer.tsx`, `Wordmark.tsx`, `Icons.tsx`.

## Screenshots

Transparent, device-framed PNGs live in `public/shots/`
(`models`, `recording`, `entry`, `home` at `@2x`). They are wired in
`lib/site.ts` (`SHOTS` for the hero fan, `STEPS` for the how-it-works device).
Swap the files or edit those arrays to change them.

The copy stays engine-neutral, the same as the app. The hover pop on the fan
is deliberately not gated behind `prefers-reduced-motion`; ambient motion is.
