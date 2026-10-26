import Image from "next/image";
import { LangProvider } from "@/components/LangProvider";
import { Replica } from "@/components/replica/Replica";
import { pick, type Lang } from "@/lib/lang";

/**
 * The share card (public/cleen-og.png), as a page so it's drawn with the site's own
 * replica: the open notch hanging from the top edge, as if the image were the top of a
 * Mac screen, and the name and line centered below. Photographed at 1200×630 by
 * scripts/og.mjs (/og and /en/og); not linked anywhere and kept out of search.
 */
export function ShareCard({ lang }: { lang: Lang }) {
  const l = pick(lang);
  return (
    <LangProvider lang={lang}>
    <main className="relative flex h-[630px] w-[1200px] flex-col items-center overflow-hidden bg-[#f5f5f7] text-ink">
      <div className="origin-top scale-[1.08]">
        <Replica label={l("O Cleen aberto no notch, no Início", "Cleen open in the notch, on Home")} tab="home" bare />
      </div>
      <div className="flex flex-1 flex-col items-center justify-center pb-12 text-center">
        <div className="flex items-center gap-3">
          <Image src="/cleen-icon.png" alt="" width={52} height={52} unoptimized />
          <span className="text-[30px] font-semibold tracking-[-0.01em]">Cleen</span>
        </div>
        <h1 className="mt-4 text-[54px] font-semibold leading-[1.05] tracking-[-0.025em]">{l("Tudo no notch do seu Mac.", "Everything in your Mac’s notch.")}</h1>
        <p className="mt-3 text-[24px] leading-[1.3] tracking-[-0.005em] text-mute">{l("Limpeza, busca e quase trinta ferramentas. Grátis.", "Cleanup, search and nearly thirty tools. Free.")}</p>
      </div>
    </main>
    </LangProvider>
  );
}
