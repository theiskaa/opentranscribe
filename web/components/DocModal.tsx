"use client";

import { useEffect, useRef, useState } from "react";
import { createPortal } from "react-dom";
import Markdown from "./Markdown";
import { stripPreamble, type Doc } from "@/lib/docs";
import { GITHUB_URL, GITHUB_RAW } from "@/lib/site";

const cache = new Map<string, string>();

let scrollLocks = 0;

function lockScroll() {
  scrollLocks += 1;
  if (scrollLocks === 1) document.body.style.overflow = "hidden";
}

function unlockScroll() {
  scrollLocks -= 1;
  if (scrollLocks === 0) document.body.style.overflow = "";
}

export default function DocModal({ doc, onClose }: { doc: Doc; onClose: () => void }) {
  const [content, setContent] = useState<string | null>(() => cache.get(doc.file) ?? null);
  const [failed, setFailed] = useState(false);
  const panel = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (cache.has(doc.file)) return;
    let live = true;
    fetch(`${GITHUB_RAW}/${doc.file}`)
      .then((res) => {
        if (!res.ok) throw new Error(String(res.status));
        return res.text();
      })
      .then((text) => {
        cache.set(doc.file, text);
        if (live) setContent(text);
      })
      .catch(() => {
        if (live) setFailed(true);
      });
    return () => {
      live = false;
    };
  }, [doc.file]);

  useEffect(() => {
    const opener = document.activeElement instanceof HTMLElement ? document.activeElement : null;
    lockScroll();
    panel.current?.focus();
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") onClose();
    };
    window.addEventListener("keydown", onKey);
    return () => {
      unlockScroll();
      window.removeEventListener("keydown", onKey);
      opener?.focus();
    };
  }, [onClose]);

  const source = `${GITHUB_URL}/blob/main/${doc.file}`;

  return createPortal(
    <div
      className="doc-scrim fixed inset-0 z-[80] flex items-end justify-center bg-canvas/70 backdrop-blur-sm sm:items-center sm:p-8"
      role="dialog"
      aria-modal="true"
      aria-label={doc.label}
      onPointerDown={(e) => {
        if (e.target === e.currentTarget) onClose();
      }}
    >
      <div
        ref={panel}
        tabIndex={-1}
        className="doc-panel flex h-[88svh] w-full max-w-2xl flex-col overflow-hidden rounded-t-[28px] border border-line bg-canvas outline-none sm:h-auto sm:max-h-[80svh] sm:rounded-[28px]"
      >
        <div className="flex items-center justify-between gap-4 border-b border-line px-6 py-4 sm:px-8">
          <p className="t-subhead font-semibold text-ink">{doc.label}</p>
          <div className="flex items-center gap-5">
            <a
              href={source}
              target="_blank"
              rel="noreferrer"
              className="t-footnote transition-colors duration-200 hover:text-ink"
            >
              GitHub ↗
            </a>
            <button
              type="button"
              onClick={onClose}
              aria-label="Close"
              className="t-footnote -mr-1 px-1 text-ink-2 transition-colors duration-200 hover:text-ink"
            >
              ✕
            </button>
          </div>
        </div>

        <div className="overflow-y-auto overscroll-contain px-6 py-8 sm:px-8">
          {failed ? (
            <p className="t-body text-ink-2">
              This could not be loaded.{" "}
              <a
                href={source}
                target="_blank"
                rel="noreferrer"
                className="text-ink underline decoration-line underline-offset-4 hover:decoration-ink"
              >
                Read it on GitHub
              </a>
              .
            </p>
          ) : content === null ? (
            <p className="t-body text-ink-2">Loading…</p>
          ) : (
            <Markdown>{doc.stripPreamble ? stripPreamble(content) : content}</Markdown>
          )}
        </div>
      </div>
    </div>,
    document.body,
  );
}
