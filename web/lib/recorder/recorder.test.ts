import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

import { waveformLevel } from "./level.ts";
import { sceneVoiceLevel } from "./voice.ts";
import { formatElapsed, speakingAt, tokensShownBy } from "./schedule.ts";
import { firstDivergence, packIncrementally, packLines, transcriptWords } from "./pack.ts";
import { rollingSlots } from "./rolling.ts";

const read = (name: string) => JSON.parse(readFileSync(new URL(name, import.meta.url), "utf8"));
const take = read("./take.json");
const vectors = read("./vectors.json");
const near = (a: number, b: number) => assert.ok(Math.abs(a - b) < 1e-9, `${a} is not ${b}`);
const widthOf = (word: string) => word.length * 9;

test("a level is shaped into a bar height exactly as the app shapes it", () => {
  for (const [raw, shaped] of vectors.waveformLevel) near(waveformLevel(raw), shaped);
});

test("the voice speaks, rests and lands its words at the app's own moments", () => {
  for (const [ms, speaking, level, shown] of vectors.voice) {
    assert.equal(speakingAt(ms, take.bursts), speaking);
    near(sceneVoiceLevel(ms, speaking), level);
    assert.equal(tokensShownBy(ms, take.landings), shown);
  }
});

test("a burst starts on its first instant and a word lands on its own, not one before", () => {
  for (const [ms, speaking, shown] of vectors.edges) {
    assert.equal(speakingAt(ms, take.bursts), speaking);
    assert.equal(tokensShownBy(ms, take.landings), shown);
  }
});

test("every word of the take has landed before it stops", () => {
  assert.equal(tokensShownBy(take.lengthMs, take.landings), take.tokens.length);
});

test("text splits into the words the app's window lays out", () => {
  for (const sample of [vectors.words, vectors.cjkWords, ...vectors.oddWords]) {
    const { words, glued } = transcriptWords(sample.text);
    assert.deepEqual(words, sample.words);
    assert.deepEqual(glued, sample.glued);
  }
});

test("lines pack greedily to the same breaks as the app at any width", () => {
  const { words, glued } = vectors.words;
  for (const { maxWidth, lines } of vectors.packLines) {
    assert.deepEqual(packLines(words, widthOf, { spaceWidth: 4, maxWidth, glued }), lines);
  }
});

test("a growing take repacks only its tail and still matches the app line for line", () => {
  let previousWords: string[] = [];
  let previousGlued: boolean[] = [];
  let previous: number[][] = [];
  let previousMaxWidth: number | null = null;
  for (const { shown, lines } of vectors.packIncrementally) {
    const { words, glued } = transcriptWords(take.tokens.slice(0, shown).join(take.joiner));
    const packed = packIncrementally(words, widthOf, {
      spaceWidth: 4,
      maxWidth: 322,
      glued,
      previousWords,
      previous,
      previousMaxWidth,
      previousGlued,
    });
    assert.deepEqual(packed, lines);
    previousWords = words;
    previousGlued = glued;
    previous = packed;
    previousMaxWidth = 322;
  }
});

test("a revised, shrunk or emptied take repacks to what packing it whole would give", () => {
  let previousWords: string[] = [];
  let previousGlued: boolean[] = [];
  let previous: number[][] = [];
  for (const { text, lines } of vectors.packRevisions) {
    const { words, glued } = transcriptWords(text);
    const packed = packIncrementally(words, widthOf, {
      spaceWidth: 4,
      maxWidth: 120,
      glued,
      previousWords,
      previous,
      previousMaxWidth: 120,
      previousGlued,
    });
    assert.deepEqual(packed, lines);
    assert.deepEqual(packed, packLines(words, widthOf, { spaceWidth: 4, maxWidth: 120, glued }));
    previousWords = words;
    previousGlued = glued;
    previous = packed;
  }
});

test("an unchanged take hands back the very packing it had", () => {
  const { words, glued } = vectors.words;
  const previous = packLines(words, widthOf, {
    spaceWidth: 4,
    maxWidth: 322,
    glued,
  });
  const again = packIncrementally(words, widthOf, {
    spaceWidth: 4,
    maxWidth: 322,
    glued,
    previousWords: words,
    previous,
    previousMaxWidth: 322,
    previousGlued: glued,
  });
  assert.equal(again, previous);
});

test("two takes diverge at the first word that differs", () => {
  for (const { a, b, at } of vectors.firstDivergence) assert.equal(firstDivergence(a, b), at);
});

test("the same words diverge where a space came or went between them", () => {
  for (const { a, b, aGlued, bGlued, at } of vectors.gluedDivergence) {
    assert.equal(firstDivergence(a, b, aGlued, bGlued), at);
  }
});

test("only the digits that changed roll when the clock ticks", () => {
  for (const { from, to, slots } of vectors.rollingSlots) {
    assert.deepEqual(rollingSlots(from, to), slots);
  }
});

test("a clock that grows or shrinks rolls whole graphemes in and out", () => {
  for (const { from, to, slots } of vectors.rollingGrowth) {
    assert.deepEqual(rollingSlots(from, to), slots);
  }
});

test("the clock reads mm:ss and grows hours only when a take has them", () => {
  for (const [seconds, text] of vectors.formatElapsed) assert.equal(formatElapsed(seconds), text);
});
