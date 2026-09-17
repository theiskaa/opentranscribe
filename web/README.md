# opentranscribe web

The landing page for opentranscribe. A single dark page: a hero around a live
port of the app's recorder, then the feature panels, the engines, the club and
the privacy cards. Next.js, Tailwind, TypeScript. A visitor's browser talks to
no third party.

```sh
pnpm install
pnpm dev        # http://localhost:3000
pnpm build
pnpm lint
pnpm test       # node --test over lib/**/*.test.ts, needs Node 22.6 or newer
```

## Where things live

- `app/page.tsx`: the page. Hero, then `#features`, `#engines`, `#club` and
  `#privacy`.
- `lib/site.ts`: links and all copy, section data included. No copy lives in a
  component.
- `lib/wave.ts`: the waveform mark's path data.
- `lib/canvas.ts`: the ink colour and the 8x8 Bayer matrix the dither draws with.
- `app/globals.css`: the tokens, the type scale (`t-hero`, `t-display`,
  `t-title`, ...), the shared `panel` and `app-card` surfaces, and the hover and
  press feedback.
- `components/`
  - `Hero.tsx`: the copy over three phones: the live recorder, with home and a
    reflection dimmed beside it. `HeroHalo.tsx` holds the dither to the screen
    and fades it out within a short scroll.
  - `FeaturePanels.tsx`, `Engines.tsx`, `Club.tsx`, `Audit.tsx`: the sections.
  - `DitherCorner.tsx`: the ordered dither, from the top or the top right.
  - `Sf.tsx` and `sfGlyphs.ts`: outlines from the app's own icon font.
  - `Nav.tsx`, `Footer.tsx`, `Wordmark.tsx`, `Icons.tsx`, and the changelog and
    license modal (`DocLink.tsx`, `DocModal.tsx`, `Markdown.tsx`).

## The recorder

`components/recorder/` is the app's recording screen ported value for value:
the band (`Waveform.tsx`, a canvas), the live words (`liveWindow.ts`, kept
outside React), the rolling clock, and the control row, laid over the
screenshots' own bezel at real points. It plays the take the app's onboarding
plays.

`lib/recorder/` holds the pure ports (level shaping, the scene's voice, line
packing, the rolling diff, the curves) and their tests. The take and the test
vectors are not written by hand: from the repo root,

```sh
flutter test tool/web_take.dart
```

runs the app's own scheduling code and writes `take.json` and `vectors.json`.
Run it again whenever the onboarding's text or timing changes.

## Screenshots and icons

Transparent, device-framed PNGs live in `public/shots/` (`recording`, `entry`,
`reflections`, `home`, `models` at `@2x`), wired in `lib/site.ts`. The club's
icon art in `public/icons/` is exported from the app's appiconsets.

Nothing on the page moves on its own but the recorder, and nothing enters with
an animation. Hover and press feedback is deliberately not gated behind
`prefers-reduced-motion`.
