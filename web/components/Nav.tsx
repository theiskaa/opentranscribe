"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { APP_STORE_URL, GITHUB_URL } from "@/lib/site";
import { WaveMark } from "./Wordmark";
import { AppleIcon, GithubIcon } from "./Icons";

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

        <div className="flex items-center gap-5 sm:gap-6">
          <a
            href={GITHUB_URL}
            target="_blank"
            rel="noreferrer"
            aria-label="GitHub"
            className="inline-flex items-center gap-2 text-[13px] font-medium text-ink-2 transition-colors duration-200 hover:text-ink"
          >
            <GithubIcon className="h-4 w-4" />
            <span className="hidden sm:inline">GitHub</span>
          </a>
          <a
            href={APP_STORE_URL}
            target="_blank"
            rel="noreferrer"
            className="btn-ghost gap-1.5 px-4 py-2 text-[13px]"
          >
            <AppleIcon className="h-3.5 w-3.5" />
            Download
          </a>
        </div>
      </nav>
    </header>
  );
}
