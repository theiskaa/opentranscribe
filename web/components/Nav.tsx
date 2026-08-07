"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
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
        scrolled
          ? "border-b border-line bg-canvas/80 backdrop-blur-md"
          : "border-b border-transparent"
      }`}
    >
      <nav className="mx-auto flex h-16 w-full max-w-frame items-center justify-between px-6 sm:px-12">
        <Link
          href="/#top"
          className="flex items-center gap-2.5 text-[15px] font-semibold tracking-[-0.24px] text-ink"
        >
          <WaveMark className="h-4 w-auto" />
          OpenTranscribe
        </Link>

        <a
          href={GITHUB_URL}
          target="_blank"
          rel="noreferrer"
          className="inline-flex items-center gap-2 text-[13px] font-medium text-ink-2 transition-colors duration-200 hover:text-ink"
        >
          <GithubIcon className="h-4 w-4" />
          GitHub
        </a>
      </nav>
    </header>
  );
}
