"use client";

import { ArrowLeftRight, Check, ChevronsUpDown, Copy } from "lucide-react";
import type { ReactNode, Ref } from "react";
import { notch } from "../../style";
import { categories, type CategoryId, type Unit } from "./units";

/** The nine categories as one pill row, white for the chosen one (NotchSegmented). */
export function CategoryBar({ selected, onSelect }: { selected: CategoryId; onSelect: (id: CategoryId) => void }) {
  return (
    <div className="shrink-0 overflow-x-auto [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
      <div role="radiogroup" aria-label="Categoria" className="flex w-fit gap-0.5 rounded-full p-0.5" style={{ background: notch.control }}>
        {categories.map(({ id, title }) => {
          const isSelected = id === selected;
          return (
            <button
              key={id}
              type="button"
              role="radio"
              aria-checked={isSelected}
              onClick={() => onSelect(id)}
              className="h-[22px] whitespace-nowrap rounded-full px-[9px] text-[11px] font-medium transition-[background-color,color] duration-200"
              style={{ background: isSelected ? "#fff" : "transparent", color: isSelected ? "#000" : "rgba(255,255,255,0.75)" }}
            >
              {title}
            </button>
          );
        })}
      </div>
    </div>
  );
}

/**
 * The unit's name with the up-down chevron, drawn the way macOS lays out a borderless
 * Menu (chevron first, label colour). The list is the browser's own menu (a native
 * select laid over the label), so it opens past the panel like the app's.
 */
export function UnitMenu({ units, selected, onSelect }: { units: Unit[]; selected: Unit; onSelect: (id: string) => void }) {
  return (
    <span className="relative inline-flex w-fit items-center gap-1 text-white/90 transition-colors duration-150 hover:text-white">
      <ChevronsUpDown size={10} strokeWidth={2.6} aria-hidden className="shrink-0" />
      <span className="truncate text-[11.5px] font-medium">{selected.name}</span>
      <select
        value={selected.id}
        onChange={(event) => onSelect(event.target.value)}
        aria-label={`Unidade: ${selected.name}`}
        className="absolute inset-0 cursor-pointer appearance-none opacity-0"
      >
        {units.map((unit) => (
          <option key={unit.id} value={unit.id}>
            {unit.name === unit.symbol ? unit.name : `${unit.name} (${unit.symbol})`}
          </option>
        ))}
      </select>
    </span>
  );
}

/**
 * One side of the conversion on the notch's card: the big number, its unit under it.
 * The result side shows a copy button on hover and "Copiado" once copied.
 */
export function ConverterBox({ children, unit, copy }: { children: ReactNode; unit: ReactNode; copy?: { copied: boolean; live: boolean; onCopy: () => void } }) {
  return (
    <div
      className="group relative flex min-w-0 flex-1 flex-col justify-center gap-[3px] rounded-[12px] py-2.5 pl-3.5 pr-2.5"
      style={{ background: notch.card, boxShadow: `inset 0 0 0 1px ${notch.cardStroke}` }}
    >
      {children}
      {unit}
      {copy && (
        <div className="absolute right-1.5 top-1.5">
          {copy.copied ? (
            <span role={copy.live ? "status" : undefined} className="flex h-[22px] items-center gap-1 rounded-full px-2 text-[10.5px] font-medium" style={{ background: notch.control, color: notch.good }}>
              <Check size={10} strokeWidth={2.8} aria-hidden />
              Copiado
            </span>
          ) : (
            <button
              type="button"
              onClick={copy.onCopy}
              aria-label="Copiar resultado"
              title="Copiar resultado"
              className="flex h-6 w-[26px] items-center justify-center rounded-[7px] opacity-0 transition-[opacity,background-color,color] duration-150 hover:bg-white/10 hover:text-white focus-visible:opacity-100 group-hover:opacity-100 text-white/55"
            >
              <Copy size={12} strokeWidth={2.1} aria-hidden />
            </button>
          )}
        </div>
      )}
    </div>
  );
}

/** The round swap between the boxes; the arrows turn half a circle each time. */
export function SwapButton({ onSwap, glyph }: { onSwap: () => void; glyph: Ref<HTMLSpanElement> }) {
  return (
    <button
      type="button"
      onClick={onSwap}
      aria-label="Inverter unidades"
      title="Inverter unidades"
      className="flex size-[30px] shrink-0 items-center justify-center self-center rounded-full bg-white/10 transition-[background-color,color] duration-150 hover:bg-white/[0.16] hover:text-white text-white/55"
    >
      <span ref={glyph} className="flex">
        <ArrowLeftRight size={13} strokeWidth={2.4} aria-hidden />
      </span>
    </button>
  );
}
