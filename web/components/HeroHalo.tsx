"use client";

import { useEffect, useRef } from "react";
import DitherCorner from "./DitherCorner";

const FADE_OVER_PX = 300;

// Held to the viewport and gone within a short scroll, so the page slides over it.
export default function HeroHalo() {
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    let raf = 0;
    const update = () => {
      raf = 0;
      el.style.opacity = Math.max(0, 1 - window.scrollY / FADE_OVER_PX).toFixed(3);
    };
    const onScroll = () => {
      if (!raf) raf = requestAnimationFrame(update);
    };
    update();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => {
      window.removeEventListener("scroll", onScroll);
      cancelAnimationFrame(raf);
    };
  }, []);

  return (
    <div
      ref={ref}
      aria-hidden
      className="pointer-events-none fixed inset-x-0 top-0 -z-10 h-[640px]"
    >
      <DitherCorner from="top" className="h-full w-full" />
    </div>
  );
}
