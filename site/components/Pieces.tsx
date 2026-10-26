import { pick, type Lang } from "@/lib/lang";

/** ⌥ and Space as physical keys. */
export function Keycaps({ lang }: { lang: Lang }) {
  const l = pick(lang);
  const key = "inline-flex h-16 items-center justify-center rounded-[14px] border border-black/10 bg-gradient-to-b from-white to-[#ececf0] text-[26px] font-medium text-ink shadow-[0_1px_0_rgba(255,255,255,0.9)_inset,0_6px_14px_rgba(0,0,0,0.12)]";
  return (
    <div className="flex items-center justify-center gap-3" aria-label={l("Atalho Option Espaço", "Option Space shortcut")}>
      <kbd className={`${key} w-16`}>⌥</kbd>
      <span className="text-[24px] text-faint">+</span>
      <kbd className={`${key} w-52 text-[20px]`}>{l("espaço", "space")}</kbd>
    </div>
  );
}
