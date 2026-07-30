"use client";

import Image from "next/image";
import { useEffect, useRef } from "react";
import { SHOTS, SHOT_W, SHOT_H } from "@/lib/site";

const POSE = [
  { ty: 18, rot: -9 },
  { ty: 4, rot: -3 },
  { ty: 4, rot: 3 },
  { ty: 18, rot: 9 },
];
const Z = ["z-[1]", "z-[2]", "z-[3]", "z-[4]"];

export default function Screenshots() {
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const el = ref.current;
    if (!el) return;
    const io = new IntersectionObserver(
      (entries) => {
        for (const e of entries) {
          if (e.isIntersecting) {
            el.classList.add("in");
            io.unobserve(el);
          }
        }
      },
      { threshold: 0.25, rootMargin: "0px 0px -10% 0px" },
    );
    io.observe(el);
    return () => io.disconnect();
  }, []);

  return (
    <div ref={ref} className="shotfan -mt-6 flex items-end justify-center px-4 sm:-mt-12">
      {SHOTS.map((shot, i) => (
        <div
          key={shot.src}
          className={`shot-enter group relative -mx-[4vw] w-[42vw] max-w-[248px] hover:z-50 sm:-mx-[2vw] sm:w-[22vw] ${Z[i]}`}
        >
          <div
            style={
              { "--ty": `${POSE[i].ty}px`, "--rot": `${POSE[i].rot}deg` } as React.CSSProperties
            }
            className="relative origin-bottom [transform:translateY(calc(var(--ty)_+_var(--lift,0px)))_rotate(calc(var(--rot)_*_var(--rotm,1)))_scale(var(--s,1))] transition-transform duration-[480ms] ease-settle group-hover:duration-[380ms] group-hover:ease-spring group-hover:[--lift:-28px] group-hover:[--rotm:0.35] group-hover:[--s:1.07]"
          >
            <Image
              src={shot.src}
              alt={shot.cap}
              width={SHOT_W}
              height={SHOT_H}
              className="h-auto w-full select-none transition-[filter] duration-[480ms] [filter:drop-shadow(0_28px_55px_rgba(0,0,0,0.65))] group-hover:duration-[380ms] group-hover:[filter:drop-shadow(0_56px_100px_rgba(0,0,0,0.9))]"
              sizes="(min-width: 640px) 248px, 42vw"
              draggable={false}
              priority
            />
          </div>
        </div>
      ))}
    </div>
  );
}
