"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { APP_STORE_URL } from "@/lib/site";
import { WaveMark } from "./Wordmark";

const SECTIONS = [
  ["Engines", "/#engines"],
  ["Club", "/#club"],
] as const;

const item =
  "inline-flex items-center text-[14px] font-medium text-ink-2 transition-colors duration-200 hover:text-ink";

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

        <div className="flex items-center gap-6 sm:gap-8">
          {SECTIONS.map(([label, href]) => (
            <Link key={href} href={href} className={`${item} hidden md:inline`}>
              {label}
            </Link>
          ))}
          <a href={APP_STORE_URL} target="_blank" rel="noreferrer" className={item}>
            Download
          </a>
        </div>
      </nav>
    </header>
  );
}
