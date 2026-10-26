"use client";

import { Check, Plus } from "lucide-react";
import { useL } from "@/components/LangProvider";
import { notch } from "../../style";
import type { Listing } from "./market";

/** macOS's mini spinner (ProgressView .mini): eight fading spokes turning in steps. */
export function Spinner({ size = 12 }: { size?: number }) {
  return (
    <svg aria-hidden width={size} height={size} viewBox="0 0 16 16" className="shrink-0 animate-[spin_0.8s_steps(8)_infinite] motion-reduce:animate-none">
      {Array.from({ length: 8 }, (_, spoke) => (
        <line key={spoke} x1="8" y1="1.6" x2="8" y2="4.6" stroke="white" strokeWidth="1.7" strokeLinecap="round" opacity={0.25 + (spoke / 7) * 0.75} transform={`rotate(${spoke * 45} 8 8)`} />
      ))}
    </svg>
  );
}

/** SF's xmark.circle.fill: a grey disc with the cross cut out of it. */
export function ClearGlyph({ size = 12 }: { size?: number }) {
  return (
    <svg aria-hidden width={size} height={size} viewBox="0 0 16 16">
      <circle cx="8" cy="8" r="7.5" fill="currentColor" />
      <path d="M5.4 5.4l5.2 5.2M10.6 5.4l-5.2 5.2" stroke="black" strokeWidth="1.6" strokeLinecap="round" />
    </svg>
  );
}

/**
 * One search hit (StockSearchRow): the ticker, the company, the exchange, and a + to
 * add it, or a check when it's already on the list.
 */
export function SearchHit({
  item,
  selected,
  listed,
  adding,
  onPick,
}: {
  item: Listing;
  selected: boolean;
  listed: boolean;
  adding: boolean;
  onPick: () => void;
}) {
  const l = useL();
  return (
    <button
      type="button"
      onClick={onPick}
      disabled={listed}
      aria-label={`${item.symbol}, ${item.name}`}
      aria-description={listed ? l("Já está na lista", "Already on the list") : l("Adicionar à lista", "Add to list")}
      data-selected={selected || undefined}
      className="group flex h-[26px] min-w-0 items-center gap-2 rounded-[8px] px-2 text-left transition-[background-color] duration-[120ms] hover:bg-white/[0.06] data-selected:bg-white/[0.14] disabled:cursor-default"
    >
      <span className="min-w-12 shrink-0 text-[12px] font-semibold">{item.symbol}</span>
      <span className="min-w-0 flex-1 truncate text-[10.5px]" style={{ color: notch.secondary }}>{item.name}</span>
      <span className="shrink-0 text-[10.5px]" style={{ color: notch.tertiary }}>{item.exchange}</span>
      <span className="flex w-3.5 shrink-0 justify-center">
        {adding ? (
          <Spinner size={11} />
        ) : listed ? (
          <Check size={11} strokeWidth={2.4} style={{ color: notch.good }} aria-hidden />
        ) : (
          <Plus
            size={11}
            strokeWidth={2.4}
            aria-hidden
            className="text-white/[0.32] transition-[color] duration-[120ms] group-hover:text-white group-data-selected:text-white"
          />
        )}
      </span>
    </button>
  );
}
