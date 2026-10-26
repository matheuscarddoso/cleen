"use client";

import { useEffect, useState } from "react";
import { useL } from "@/components/LangProvider";
import type { Lang } from "@/lib/lang";
import { notch } from "../../style";
import type { IconEntry } from "./catalog";

/** What a cell can copy, and the pill once it's on the clipboard (LucideCopyKind). */
export type CopyKind = "svg" | "name" | "jsx" | "html";

export const copiedLabel: Record<CopyKind, string> = {
  svg: "SVG copiado",
  name: "Nome copiado",
  jsx: "JSX copiado",
  html: "HTML copiado",
};

export const copiedLabels: Record<Lang, Record<CopyKind, string>> = {
  pt: copiedLabel,
  en: { svg: "SVG copied", name: "Name copied", jsx: "JSX copied", html: "HTML copied" },
};

/** The cell's context menu, in the app's order; the last item opens the icon's page. */
export const menuItems: { label: string; kind: CopyKind | "page" }[] = [
  { label: "Copiar SVG", kind: "svg" },
  { label: "Copiar nome", kind: "name" },
  { label: "Copiar JSX", kind: "jsx" },
  { label: "Copiar como Blade/HTML", kind: "html" },
  { label: "Abrir em lucide.dev", kind: "page" },
];

const englishMenuItems: typeof menuItems = [
  { label: "Copy SVG", kind: "svg" },
  { label: "Copy Name", kind: "name" },
  { label: "Copy JSX", kind: "jsx" },
  { label: "Copy as Blade/HTML", kind: "html" },
  { label: "Open on lucide.dev", kind: "page" },
];

export function menuItemsFor(lang: Lang): typeof menuItems {
  return lang === "en" ? englishMenuItems : menuItems;
}

let measurer: CanvasRenderingContext2D | null = null;

/** Kebab names share their starts ("circle-…"), so the middle goes, not the end. */
function middleTruncate(text: string, width: number): string {
  measurer ??= document.createElement("canvas").getContext("2d");
  const context = measurer;
  if (!context) return text;
  context.font = '9.5px -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif';
  const fits = (value: string) => context.measureText(value).width <= width;
  if (fits(text)) return text;
  for (let keep = text.length - 1; keep > 1; keep -= 1) {
    const candidate = `${text.slice(0, Math.ceil(keep / 2))}…${text.slice(text.length - Math.floor(keep / 2))}`;
    if (fits(candidate)) return candidate;
  }
  return text;
}

/** The icon's name under the glyph: full on the server, middle-truncated once measured. */
function CellName({ name, hovered }: { name: string; hovered: boolean }) {
  const [shown, setShown] = useState(name);
  useEffect(() => setShown(middleTruncate(name, 63)), [name]);
  return (
    <span
      className={`max-w-full overflow-hidden whitespace-nowrap text-[9.5px] leading-[12px] transition-colors duration-150 group-hover:text-white/85 ${hovered ? "text-white/85" : "text-white/55"}`}
    >
      {shown}
    </span>
  );
}

/**
 * One icon (IconCell): the glyph large, its name small under it, on the card. The top
 * search result gets a brighter outline: it's what Return copies.
 */
export function IconCell({
  entry,
  suggested,
  hovered,
  pressed,
  onCopy,
  onMenu,
}: {
  entry: IconEntry;
  suggested: boolean;
  hovered: boolean;
  pressed: boolean;
  onCopy: (entry: IconEntry, kind: CopyKind) => void;
  onMenu: (entry: IconEntry, at: { clientX: number; clientY: number }) => void;
}) {
  const l = useL();
  const Glyph = entry.icon;
  return (
    <button
      type="button"
      data-icon={entry.name}
      onClick={() => onCopy(entry, "svg")}
      onContextMenu={(event) => {
        event.preventDefault();
        onMenu(entry, event);
      }}
      title={entry.name}
      aria-label={entry.name}
      aria-description={l("Copia o SVG", "Copies the SVG")}
      className={`group flex h-16 flex-col items-center justify-center gap-[5px] rounded-[10px] px-1 transition-[background-color,box-shadow,scale] duration-150 hover:bg-white/10 active:scale-[0.94] ${hovered ? "bg-white/10" : "bg-white/[0.045]"}`}
      style={{
        boxShadow: `inset 0 0 0 1px ${suggested ? "rgba(255,255,255,0.35)" : notch.cardStroke}`,
        scale: pressed ? "0.94" : undefined,
      }}
    >
      <Glyph size={32} strokeWidth={2} aria-hidden className={`shrink-0 transition-colors duration-150 group-hover:text-white ${hovered ? "text-white" : "text-white/88"}`} />
      <CellName name={entry.name} hovered={hovered} />
    </button>
  );
}

/**
 * The cell's context menu, drawn the way macOS draws one in dark mode: translucent
 * dark panel, hairline edge, the hovered item in the accent blue.
 */
export function ContextMenu({
  at,
  active,
  focusFirst,
  onPick,
  onClose,
}: {
  at: { x: number; y: number };
  /** The item the script's pointer is on; null when the visitor opened it (focus goes in). */
  active: number | null;
  /** Opened by the visitor: the first item takes the keyboard. Never for the script. */
  focusFirst: boolean;
  onPick: (kind: CopyKind | "page") => void;
  onClose: () => void;
}) {
  const l = useL();
  return (
    <>
      <button type="button" aria-label={l("Fechar menu", "Close menu")} className="absolute inset-0 z-20 cursor-default" onClick={onClose} onContextMenu={(event) => {
          event.preventDefault();
          onClose();
        }}
      />
      <div
        role="menu"
        className="absolute z-30 w-[168px] rounded-[9px] p-[5px] text-[12px] text-white/90"
        style={{
          left: at.x,
          top: at.y,
          background: "rgba(38,38,40,0.86)",
          backdropFilter: "blur(24px) saturate(1.6)",
          WebkitBackdropFilter: "blur(24px) saturate(1.6)",
          boxShadow: "0 0 0 0.5px rgba(0,0,0,0.6), inset 0 0 0 0.5px rgba(255,255,255,0.16), 0 10px 28px rgba(0,0,0,0.45)",
        }}
        onKeyDown={(event) => event.key === "Escape" && onClose()}
      >
        {menuItemsFor(l.lang).map((item, index) => (
          <div key={item.kind}>
            {item.kind === "page" && <div className="mx-2 my-[4px] h-px bg-white/10" />}
            <button
              type="button"
              role="menuitem"
              autoFocus={index === 0 && focusFirst}
              onClick={() => onPick(item.kind)}
              className="flex h-[21px] w-full items-center rounded-[5px] px-2 text-left transition-colors duration-75 hover:bg-[#0a72e6] hover:text-white focus-visible:bg-[#0a72e6] focus-visible:outline-none"
              style={{ background: active === index ? "#0a72e6" : undefined }}
            >
              {item.label}
            </button>
          </div>
        ))}
      </div>
    </>
  );
}
