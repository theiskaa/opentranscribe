"use client";

import { useEffect, useState } from "react";
import { GITHUB_URL } from "@/lib/site";
import { WaveMark } from "./Wordmark";
import { GithubIcon } from "./Icons";

export default function Nav() {
  const [scrolled, setScrolled] = useState(false);

  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 64);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  return (
    <header
      className={`fixed inset-x-0 top-0 z-50 transition-colors duration-300 ${
        scrolled ? "border-b border-line bg-canvas/80 backdrop-blur-md" : "border-b border-transparent"
      }`}
    >
      <nav className="mx-auto flex h-16 w-full max-w-frame items-center justify-between px-6 sm:px-12">
        <a href="#top" className="flex items-center gap-2.5 text-[15px] font-semibold text-ink">
          <WaveMark className="h-4 w-auto" />
          OpenTranscribe
        </a>

        <a
          href={GITHUB_URL}
          target="_blank"
          rel="noreferrer"
          className="inline-flex items-center gap-2 rounded-md border border-line-strong px-3.5 py-2 text-[13px] font-medium text-ink transition-colors hover:border-ink"
        >
          <GithubIcon className="h-4 w-4" />
          GitHub
        </a>
      </nav>
    </header>
  );
}
