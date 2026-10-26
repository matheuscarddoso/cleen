import type { Metadata } from "next";
import Image from "next/image";
import { Replica } from "@/components/replica/Replica";

/**
 * The share card (public/cleen-og.png), as a page so it's drawn with the site's own
 * replica: the name and line on the left, the open notch on a Mac on the right, cut by
 * the edge like Screen Studio's. Photographed at 1200×630 by scripts/og.mjs; not linked
 * anywhere and kept out of search.
 */
export const metadata: Metadata = { title: "Cleen — imagem de compartilhamento", robots: { index: false, follow: false } };

export default function ShareCard() {
  return (
    <main className="relative h-[630px] w-[1200px] overflow-hidden bg-[#f5f5f7] text-ink">
      <div className="absolute left-[72px] top-0 flex h-full w-[440px] flex-col justify-center">
        <Image src="/cleen-icon.png" alt="" width={84} height={84} unoptimized className="-ml-1" />
        <p className="mt-5 text-[30px] font-semibold leading-none tracking-[-0.01em]">Cleen</p>
        <h1 className="mt-5 text-[54px] font-semibold leading-[1.06] tracking-[-0.025em]">Tudo no notch do seu Mac.</h1>
        <p className="mt-5 text-[24px] leading-[1.3] tracking-[-0.005em] text-mute">Limpeza, busca e quase trinta ferramentas. Grátis.</p>
      </div>
      <div className="og-stage absolute left-[560px] top-[147px] w-[680px] overflow-hidden rounded-[24px] shadow-[0_24px_60px_-20px_rgba(0,0,0,0.35),0_0_0_1px_rgba(0,0,0,0.06)]">
        <Replica label="O Cleen aberto no notch, no Início" tab="home" />
      </div>
      {/* The demo's play/pause control has no place in a still. */}
      <style>{`.og-stage button[aria-label$="demonstração"] { display: none; }`}</style>
    </main>
  );
}
