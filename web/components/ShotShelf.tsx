import Image from "next/image";
import { SHOTS, SHOT_RATIO } from "@/lib/site";
import Reveal from "./Reveal";

export default function ShotShelf() {
  return (
    <div className="mx-auto w-full max-w-frame px-6 sm:px-12">
      <Reveal stagger className="grid grid-cols-2 gap-5 sm:grid-cols-4 sm:gap-7">
        {SHOTS.map((shot) => (
          <div
            key={shot.src}
            className="[mask-image:linear-gradient(to_bottom,black_88%,transparent)]"
          >
            <div style={{ aspectRatio: SHOT_RATIO }} className="relative w-full">
              <Image
                src={shot.src}
                alt={shot.cap}
                fill
                sizes="(min-width: 640px) 25vw, 45vw"
                className="select-none object-cover object-top"
                draggable={false}
                priority
              />
            </div>
          </div>
        ))}
      </Reveal>
    </div>
  );
}
