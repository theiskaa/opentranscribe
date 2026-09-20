import type { ReactNode } from "react";
import { AUDIT, ENGINES, FEATURES_INTRO } from "@/lib/site";
import Nav from "@/components/Nav";
import Hero from "@/components/Hero";
import FeaturePanels from "@/components/FeaturePanels";
import Engines from "@/components/Engines";
import Audit from "@/components/Audit";
import Club from "@/components/Club";
import Footer from "@/components/Footer";

type Intro = { title: string; lead: string };

function Section({ id, intro, children }: { id: string; intro?: Intro; children: ReactNode }) {
  return (
    <section id={id} className="scroll-mt-24 border-t border-line">
      <div className="mx-auto w-full max-w-frame px-6 py-20 sm:px-12 sm:py-24">
        {intro && (
          <>
            <h2 className="t-display">{intro.title}</h2>
            <p className="t-body mt-5 max-w-[56ch] text-ink-2">{intro.lead}</p>
          </>
        )}
        {children}
      </div>
    </section>
  );
}

export default function Home() {
  return (
    <>
      <Nav />
      <main id="top">
        <Hero />

        <Section id="features" intro={FEATURES_INTRO}>
          <FeaturePanels />
        </Section>

        <Section id="engines" intro={ENGINES}>
          <Engines />
        </Section>

        <Section id="club">
          <Club />
        </Section>

        <Section id="privacy" intro={AUDIT}>
          <Audit />
        </Section>
      </main>
      <Footer />
    </>
  );
}
