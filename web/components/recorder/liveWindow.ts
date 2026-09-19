import { easeInOut } from "@/lib/recorder/curves";
import { packIncrementally, transcriptWords } from "@/lib/recorder/pack";
import { WORDS } from "./tokens";

type Classes = {
  window: string;
  line: string;
  word: string;
  wordIn: string;
  wordNew: string;
  wordOld: string;
  measure: string;
};

// The app's live window, kept outside React so a word's element lives exactly
// as long as the word: four lines on what is being said, newest at the bottom,
// scrollable back through the whole take.
export class LiveWindow {
  reduceMotion = false;

  private readonly win: HTMLDivElement;
  private readonly probe: HTMLSpanElement;
  private readonly widths = new Map<string, number>();
  private readonly spans = new Map<number, HTMLSpanElement>();
  private readonly observer: ResizeObserver;
  private text = "";
  private words: string[] = [];
  private glued: boolean[] = [];
  private lines: number[][] = [];
  private packedWidth: number | null = null;
  private shownThrough = -1;
  private following = true;
  private glide = 0;
  private maxWidth = 0;
  private lineHeight = 0;

  constructor(
    private readonly block: HTMLElement,
    private readonly classes: Classes,
  ) {
    this.probe = document.createElement("span");
    this.probe.className = classes.measure;
    this.win = document.createElement("div");
    this.win.className = classes.window;
    this.win.addEventListener("scroll", this.edges);
    block.append(this.probe, this.win);
    this.observer = new ResizeObserver(() => this.remeasure());
    this.observer.observe(block);
    document.fonts?.ready.then(() => this.remeasure());
    this.remeasure();
  }

  dispose() {
    this.observer.disconnect();
    cancelAnimationFrame(this.glide);
    this.win.removeEventListener("scroll", this.edges);
    this.probe.remove();
    this.win.remove();
  }

  setText(text: string) {
    if (text === this.text) return;
    this.text = text;
    this.layout();
  }

  private remeasure() {
    const rect = this.block.getBoundingClientRect();
    const lineHeight = rect.height / WORDS.lines;
    if (rect.width === this.maxWidth && lineHeight === this.lineHeight) return;
    this.maxWidth = rect.width;
    this.lineHeight = lineHeight;
    this.widths.clear();
    this.dropPacking();
    this.layout();
    // The repack is not a new line: nothing glides, the window rests on the newest.
    cancelAnimationFrame(this.glide);
    this.glide = 0;
    this.win.scrollTop = this.win.scrollHeight;
    this.edges();
  }

  // From the packing, not scrollHeight: the DOM rounds both heights to whole
  // pixels, and a line is rarely a whole pixel tall.
  private maxScroll(): number {
    return Math.max(0, (this.lines.length - WORDS.lines) * this.lineHeight);
  }

  private dropPacking() {
    this.words = [];
    this.glued = [];
    this.lines = [];
    this.packedWidth = null;
  }

  private widthOf = (word: string) => {
    let width = this.widths.get(word);
    if (width === undefined) {
      this.probe.textContent = word;
      width = this.probe.getBoundingClientRect().width;
      this.widths.set(word, width);
    }
    return width;
  };

  private layout() {
    if (this.maxWidth === 0) return;
    const { words, glued } = transcriptWords(this.text);
    if (words.length === 0) {
      // Only an emptied text is a fresh take.
      this.shownThrough = -1;
      this.dropPacking();
      this.spans.clear();
      this.win.replaceChildren();
      this.win.style.height = "0px";
      this.following = true;
      return;
    }
    // A shortening revision must not make words still on screen count as new.
    const shownBefore = Math.min(this.shownThrough, words.length - 1);
    this.shownThrough = words.length - 1;

    // Layout trims a lone space, so its advance is what it adds inside a run.
    const spaceWidth = this.widthOf("x x") - this.widthOf("xx");
    const previousLines = this.lines.length;
    const lines = packIncrementally(words, this.widthOf, {
      spaceWidth,
      maxWidth: this.maxWidth,
      glued,
      previousWords: this.words,
      previous: this.lines,
      previousMaxWidth: this.packedWidth,
      previousGlued: this.glued,
    });
    this.words = words;
    this.glued = glued;
    this.lines = lines;
    this.packedWidth = this.maxWidth;

    // The stagger runs over the words arriving in this frame, so a partial
    // that lands several at once reads as one cascade.
    let order = 0;
    const rows = Array.from(this.win.children) as HTMLDivElement[];
    lines.forEach((line, row) => {
      const el = rows[row] ?? this.win.appendChild(this.newLine());
      line.forEach((index, position) => {
        const space = position > 0 && !glued[index] ? spaceWidth : 0;
        const span = this.wordSpan(index, words[index], index > shownBefore ? order++ : -1);
        span.style.marginLeft = space ? `${space}px` : "";
        if (el.children[position] !== span) el.insertBefore(span, el.children[position] ?? null);
      });
      while (el.children.length > line.length) el.lastElementChild!.remove();
    });
    rows.slice(lines.length).forEach((el) => el.remove());
    for (const index of [...this.spans.keys()]) {
      if (index >= words.length) this.spans.delete(index);
    }

    // The window is only as tall as it has speech to hold, growing from the
    // top until it is full; then it scrolls, and the lift takes over.
    this.win.style.height = `${Math.min(lines.length, WORDS.lines) * this.lineHeight}px`;
    if (lines.length > previousLines) this.lift();
    else this.edges();
  }

  private newLine(): HTMLDivElement {
    const el = document.createElement("div");
    el.className = this.classes.line;
    return el;
  }

  private wordSpan(index: number, text: string, order: number): HTMLSpanElement {
    const existing = this.spans.get(index);
    if (existing) {
      if (existing.dataset.text !== text) this.revise(existing, text);
      return existing;
    }
    const span = document.createElement("span");
    span.className = this.classes.word;
    span.dataset.text = text;
    span.append(document.createElement("span"));
    span.firstElementChild!.textContent = text;
    if (order >= 0 && !this.reduceMotion) {
      span.classList.add(this.classes.wordIn);
      span.style.animationDelay = `${order * WORDS.staggerMs}ms`;
      // Moved to another line later, a finished entrance must not replay.
      span.addEventListener(
        "animationend",
        () => {
          span.classList.remove(this.classes.wordIn);
          span.style.animationDelay = "";
        },
        { once: true },
      );
    }
    this.spans.set(index, span);
    return span;
  }

  // A revision dissolves in place: the new word alone sizes the slot and the
  // one it replaced fades out over the top of it.
  private revise(span: HTMLSpanElement, text: string) {
    span.dataset.text = text;
    const old = document.createElement("span");
    old.className = this.classes.wordOld;
    old.textContent = span.lastElementChild!.textContent;
    old.addEventListener("animationend", () => old.remove(), { once: true });
    const next = document.createElement("span");
    next.className = this.classes.wordNew;
    next.textContent = text;
    span.replaceChildren(old, next);
  }

  // A new line lands below the window with the words above it held where they
  // are, then the window glides down to it. A reader scrolled back is left be.
  private lift() {
    const target = this.maxScroll();
    if (target <= 0 || !this.following) return this.edges();
    cancelAnimationFrame(this.glide);
    if (this.reduceMotion) {
      this.glide = 0;
      this.win.scrollTop = target;
      return this.edges();
    }
    const from = this.win.scrollTop;
    let start = 0;
    const step = (ts: number) => {
      if (!start) start = ts;
      const t = Math.min(1, (ts - start) / WORDS.lineShiftMs);
      this.win.scrollTop = from + (target - from) * easeInOut(t);
      this.glide = t < 1 ? requestAnimationFrame(step) : 0;
      this.edges();
    };
    this.glide = requestAnimationFrame(step);
    this.edges();
  }

  // Each edge softens only when speech is cut off behind it, ramping in over
  // the fade's own depth.
  private edges = () => {
    const el = this.win;
    const fade = this.lineHeight * WORDS.edgeFade;
    if (fade <= 0 || el.clientHeight === 0) return;
    const max = this.maxScroll();
    const clamp = (v: number) => Math.min(1, Math.max(0, v));
    const span = fade / el.clientHeight;
    el.style.setProperty("--top", String(clamp(el.scrollTop / fade) * span));
    el.style.setProperty("--bottom", String(clamp((max - el.scrollTop) / fade) * span));
    if (!this.glide) this.following = max - el.scrollTop <= 1.5;
  };
}
