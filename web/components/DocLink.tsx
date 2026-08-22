"use client";

import { useState } from "react";
import dynamic from "next/dynamic";
import type { Doc } from "@/lib/docs";

const DocModal = dynamic(() => import("./DocModal"), { ssr: false });

export default function DocLink({ doc, className }: { doc: Doc; className: string }) {
  const [open, setOpen] = useState(false);

  const preload = () => {
    void import("./DocModal");
  };

  return (
    <>
      <button
        type="button"
        onClick={() => setOpen(true)}
        onPointerEnter={preload}
        onFocus={preload}
        className={className}
      >
        {doc.label}
      </button>
      {open ? <DocModal doc={doc} onClose={() => setOpen(false)} /> : null}
    </>
  );
}
