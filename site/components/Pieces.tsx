import Image from "next/image";
import { Wallpaper } from "./Wallpaper";

/** ⌥ and Space as physical keys. */
export function Keycaps() {
  const key = "inline-flex h-16 items-center justify-center rounded-[14px] border border-black/10 bg-gradient-to-b from-white to-[#ececf0] text-[26px] font-medium text-ink shadow-[0_1px_0_rgba(255,255,255,0.9)_inset,0_6px_14px_rgba(0,0,0,0.12)]";
  return (
    <div className="flex items-center justify-center gap-3" aria-label="Atalho Option Espaço">
      <kbd className={`${key} w-16`}>⌥</kbd>
      <span className="text-[24px] text-faint">+</span>
      <kbd className={`${key} w-52 text-[20px]`}>espaço</kbd>
    </div>
  );
}

/** The closed notch with Claude Code working: the terminal's asterisk, cycling. */
export function ClaudeStrip() {
  return (
    <div className="relative overflow-hidden rounded-t-[22px]">
      <Wallpaper tone="dusk" />
      <div className="relative flex flex-col items-center pb-14">
        <div className="flex h-[46px] w-[min(380px,90%)] items-center justify-between rounded-b-[18px] bg-black px-5 text-[15px] font-medium text-white">
          <span className="flex items-center gap-2.5">
            <span className="claude-glyph w-5 text-center text-[20px] text-claude" aria-hidden />
            Rodando Bash
          </span>
          <span className="font-semibold tabular-nums text-white/70">12 s</span>
        </div>
        <div className="mt-8 w-[min(380px,90%)] rounded-[18px] bg-black/85 p-4 text-left text-white shadow-2xl ring-1 ring-white/10 backdrop-blur">
          <p className="flex items-center gap-2 text-[13px] font-medium">
            <Image src="/claude.svg" alt="" width={14} height={14} />
            Refatorar o checkout
          </p>
          <p className="mt-0.5 text-[12px] text-white/55">Quer rodar um comando</p>
          <p className="mt-3 rounded-[10px] bg-white/[0.07] px-3 py-2 font-mono text-[12px] text-white/85">$ npm run test</p>
          <div className="mt-3 flex justify-end gap-2 text-[12px] font-medium">
            <span className="rounded-full bg-white/10 px-3 py-1">Negar</span>
            <span className="rounded-full bg-white px-3 py-1 text-black">Permitir ⏎</span>
          </div>
        </div>
      </div>
    </div>
  );
}

/** The closed notch's live activities, one after another. */
export function LiveStack() {
  const banners = [
    { src: "/shots/live-power.png", alt: "Notch fechado avisando que o Mac está carregando, com 82%" },
    { src: "/shots/live-headphones.png", alt: "Notch fechado avisando que os AirPods Pro conectaram" },
    { src: "/shots/live-meeting.png", alt: "Notch fechado com o Claude Code trabalhando e uma reunião em 5 minutos" },
  ];
  return (
    <div className="relative overflow-hidden rounded-t-[22px]">
      <Wallpaper tone="teal" />
      <div className="relative flex flex-col items-center gap-4 pb-12">
        {banners.map((banner) => (
          <Image key={banner.src} src={banner.src} alt={banner.alt} width={1000} height={96} className="h-auto w-full select-none" draggable={false} />
        ))}
      </div>
    </div>
  );
}
