import Image from "next/image";
import { DownloadButton } from "./Buttons";
import { site } from "@/lib/site";

/** Apple's two-tier header: a thin global bar, then the product's own sticky bar. */
export function Navigation() {
  const global = [
    { href: "#busca", label: "Busca" },
    { href: "#limpeza", label: "Limpeza" },
    { href: "#claude", label: "Claude Code" },
    { href: "#ferramentas", label: "Ferramentas" },
    { href: site.repo, label: "GitHub" },
  ];
  const local = [
    { href: "#topo", label: "Visão geral" },
    { href: "#recursos", label: "Recursos" },
    { href: "#ferramentas", label: "Ferramentas" },
    { href: "#instalar", label: "Instalar" },
    { href: "#perguntas", label: "Perguntas" },
  ];
  return (
    <>
      <div className="bg-page/90 backdrop-blur-xl">
        <nav aria-label="Global" className="mx-auto flex h-11 max-w-[1000px] items-center justify-center gap-8 px-5 text-[12px] text-ink/80 md:gap-11">
          <a href="#topo" aria-label="Cleen">
            <Image src="/icon.png" alt="" width={18} height={18} />
          </a>
          {global.map((link) => (
            <a key={link.label} href={link.href} className="hidden transition-colors hover:text-ink sm:inline">
              {link.label}
            </a>
          ))}
          <a href={site.download} aria-label="Baixar o Cleen" className="transition-colors hover:text-ink">
            <svg viewBox="0 0 16 16" className="h-[14px] w-[14px]" fill="none" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round" aria-hidden>
              <path d="M8 2v8m0 0-3-3m3 3 3-3M3 13.5h10" />
            </svg>
          </a>
        </nav>
      </div>
      <header className="sticky top-0 z-50 border-b border-black/[0.08] bg-white/75 backdrop-blur-xl backdrop-saturate-[1.8]">
        <nav aria-label="Cleen" className="mx-auto flex h-[52px] max-w-[1000px] items-center justify-between px-5">
          <a href="#topo" className="text-[21px] font-semibold tracking-[-0.02em]">
            Cleen
          </a>
          <div className="flex items-center gap-6">
            <div className="hidden items-center gap-6 text-[12px] text-ink/80 md:flex">
              {local.map((link) => (
                <a key={link.label} href={link.href} className="transition-colors hover:text-link">
                  {link.label}
                </a>
              ))}
            </div>
            <DownloadButton size="sm" />
          </div>
        </nav>
      </header>
    </>
  );
}
