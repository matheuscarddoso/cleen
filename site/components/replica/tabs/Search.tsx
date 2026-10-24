"use client";

import { CircleCheck, Search } from "lucide-react";
import { useEffect, useId, useMemo, useRef, useState, type KeyboardEvent } from "react";
import { useDemo, usePlayingInterval, useTypewriter } from "../DemoContext";
import { useReplica } from "../ReplicaContext";
import { notch } from "../style";
import { results, type Item } from "./search/catalog";
import { ClearGlyph, ItemGlyph } from "./search/Glyphs";

/** What the script types, and how many times it presses ↓ once each query is in. */
const queries = ["met", "1250*12+15%", "notas", "#0071e3", "festa"] as const;
const presses = [2, 0, 0, 0, 2] as const;

/**
 * Buscar (⌥Space), as NotchSearchView lays it out: the field, then results grouped by
 * kind. The script types a window command, a calculation, an app, a color and an emoji;
 * the visitor can type for real, move with ↑/↓, run with Return and leave with Esc.
 */
export function SearchView() {
  const { playing, reduced } = useDemo();
  const { setMode, setTab } = useReplica();
  const typed = useTypewriter(queries, { hold: 2800 });
  const [moves, setMoves] = useState({ index: 0, count: 0 });
  const [manual, setManual] = useState<{ query: string; selection: number } | null>(null);
  const [focused, setFocused] = useState(false);
  const [caret, setCaret] = useState(true);
  const [done, setDone] = useState<string | null>(null);
  const [scrolled, setScrolled] = useState(false);
  const input = useRef<HTMLInputElement>(null);
  const list = useRef<HTMLDivElement>(null);
  const leave = useRef<number | undefined>(undefined);
  const id = useId();

  // Once a query is in, the script walks the selection down a row or two.
  const scriptedMoves = moves.index === typed.index && typed.finished ? moves.count : 0;
  useEffect(() => {
    const planned = presses[typed.index] ?? 0;
    if (!playing || !typed.finished || scriptedMoves >= planned) return;
    const timer = window.setTimeout(() => setMoves({ index: typed.index, count: scriptedMoves + 1 }), scriptedMoves === 0 ? 900 : 650);
    return () => window.clearTimeout(timer);
  }, [playing, scriptedMoves, typed.finished, typed.index]);

  usePlayingInterval(() => setCaret((shown) => !shown), 530);

  // Opened from the magnifier: the field takes the keyboard, like ⌥Space. Not on load.
  useEffect(() => {
    if (navigator.userActivation?.isActive) input.current?.focus({ preventScroll: true });
    return () => window.clearTimeout(leave.current);
  }, []);

  // With reduced motion the first query stands typed in, as one still.
  const scriptedQuery = reduced ? queries[0] : typed.text;
  const query = manual?.query ?? scriptedQuery;
  const sections = useMemo(() => results(query), [query]);
  const items = useMemo(() => sections.flatMap((section) => section.items), [sections]);
  const selection = items.length === 0 ? -1 : Math.min(manual?.selection ?? scriptedMoves, items.length - 1);
  const selected = items[selection];

  // Keep the selected row in view, scrolling only the list, never the page.
  useEffect(() => {
    const box = list.current;
    const row = box?.querySelector<HTMLElement>(`[data-index="${selection}"]`);
    if (!box || !row) return;
    const top = row.offsetTop - 22;
    const bottom = row.offsetTop + row.offsetHeight + 6 - box.clientHeight;
    if (box.scrollTop > top) box.scrollTop = Math.max(0, top);
    else if (box.scrollTop < bottom) box.scrollTop = bottom;
  }, [selection, sections]);

  const take = () => manual ?? { query: scriptedQuery, selection: Math.max(0, selection) };
  const move = (offset: number) => {
    const current = take();
    if (items.length === 0) return;
    setManual({ ...current, selection: (Math.max(0, Math.min(current.selection, items.length - 1)) + offset + items.length) % items.length });
  };

  const run = (item: Item | undefined) => {
    if (!item) return;
    setManual(take());
    if (item.outcome.kind === "tab") {
      setTab(item.outcome.tab);
      setMode("tool");
      return;
    }
    setDone(item.outcome.message);
    window.clearTimeout(leave.current);
    leave.current = window.setTimeout(() => setMode("tool"), 1300);
  };

  const onKeyDown = (event: KeyboardEvent<HTMLInputElement>) => {
    if (event.key === "ArrowDown" || (event.key === "Tab" && !event.shiftKey)) {
      event.preventDefault();
      move(1);
    } else if (event.key === "ArrowUp") {
      event.preventDefault();
      move(-1);
    } else if (event.key === "Enter") {
      event.preventDefault();
      run(selected);
    } else if (event.key === "Escape") {
      event.preventDefault();
      setMode("tool");
    }
  };

  const showsCaret = manual === null && !focused && !reduced && (caret || !typed.finished);

  return (
    <div className="flex h-full flex-col gap-2">
      <label
        className="relative flex h-10 shrink-0 items-center gap-2.5 rounded-[12px] px-3"
        style={{ background: notch.card, boxShadow: `inset 0 0 0 1px ${notch.cardStroke}` }}
      >
        <Search size={15} strokeWidth={2.4} className="shrink-0" style={{ color: notch.secondary }} aria-hidden />
        <span className="relative flex min-w-0 flex-1 items-center">
          <input
            ref={input}
            value={query}
            onChange={(event) => {
              setDone(null);
              setManual({ query: event.target.value, selection: 0 });
            }}
            onFocus={() => {
              setFocused(true);
              setManual(take());
            }}
            onBlur={() => setFocused(false)}
            onKeyDown={onKeyDown}
            placeholder="Buscar apps, janelas, emoji, cálculos…"
            aria-label="Buscar apps, janelas, emoji, cálculos"
            role="combobox"
            aria-expanded={items.length > 0}
            aria-controls={`${id}-results`}
            aria-activedescendant={selected ? `${id}-${selection}` : undefined}
            aria-autocomplete="list"
            autoComplete="off"
            spellCheck={false}
            className="w-full bg-transparent text-[16px] font-medium text-white caret-white outline-none placeholder:text-white/30"
            style={{ outline: "none" }}
          />
          {showsCaret && (
            <span aria-hidden className="pointer-events-none absolute left-0 top-1/2 flex -translate-y-1/2 whitespace-pre text-[16px] font-medium text-transparent">
              {query}
              <span className="ml-px h-[19px] w-[2px] rounded-full bg-white" />
            </span>
          )}
        </span>
        {query.length > 0 && (
          <button
            type="button"
            aria-label="Limpar a busca"
            title="Limpar a busca"
            onClick={() => {
              setDone(null);
              setManual({ query: "", selection: 0 });
              input.current?.focus({ preventScroll: true });
            }}
            className="-mr-0.5 flex size-5 shrink-0 items-center justify-center rounded-full transition-opacity duration-150 hover:opacity-80"
          >
            <ClearGlyph />
          </button>
        )}
      </label>

      {done ? (
        <p role="status" className="flex flex-1 animate-[numeric_300ms_ease-out] items-center justify-center gap-1.5 text-[12px] font-medium">
          <CircleCheck size={14} strokeWidth={2.2} style={{ color: notch.good }} aria-hidden />
          {done}
        </p>
      ) : items.length === 0 ? (
        <p className="flex flex-1 items-center justify-center text-[12px] font-medium" style={{ color: notch.tertiary }}>
          Nada encontrado
        </p>
      ) : (
        <div
          ref={list}
          id={`${id}-results`}
          role="listbox"
          aria-label="Resultados"
          className="relative min-h-0 flex-1 overflow-y-auto [scrollbar-width:none] [&::-webkit-scrollbar]:hidden"
          onScroll={(event) => setScrolled(event.currentTarget.scrollTop > 0)}
          style={{ maskImage: `linear-gradient(to bottom, ${scrolled ? "transparent, #000 14px" : "#000"}, #000 calc(100% - 14px), transparent)` }}
        >
          <div className="flex flex-col gap-px pb-1">
            {sections.map((section) => (
              <div key={section.title} role="group" aria-label={section.title} className="flex flex-col gap-px">
                <span aria-hidden className="px-2.5 pb-0.5 pt-1.5 text-[10.5px] font-medium leading-[13px]" style={{ color: notch.tertiary }}>
                  {section.title}
                </span>
                {section.items.map((item) => {
                  const index = items.indexOf(item);
                  return (
                    <Row
                      key={item.id}
                      id={`${id}-${index}`}
                      index={index}
                      item={item}
                      selected={index === selection}
                      onHover={() => {
                        // The pointer picks rows only once the visitor has the search.
                        if (manual && manual.selection !== index) setManual({ ...manual, selection: index });
                      }}
                      onRun={() => run(item)}
                    />
                  );
                })}
              </div>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}

/** One result (SearchRow): icon, title and subtitle, the kind on the right. */
function Row({ id, index, item, selected, onHover, onRun }: { id: string; index: number; item: Item; selected: boolean; onHover: () => void; onRun: () => void }) {
  return (
    <div
      id={id}
      data-index={index}
      role="option"
      aria-selected={selected}
      onPointerMove={onHover}
      onClick={onRun}
      className="flex h-[34px] shrink-0 cursor-default items-center gap-2.5 rounded-[9px] px-2.5"
      style={{ background: selected ? notch.selection : undefined }}
    >
      <ItemGlyph icon={item.icon} />
      <span className="truncate text-[13px] font-medium tabular-nums">{item.title}</span>
      {item.subtitle && (
        <span className="min-w-0 truncate text-[12px] tabular-nums" style={{ color: notch.tertiary }}>
          {item.subtitle}
        </span>
      )}
      <span className="min-w-2 flex-1" />
      {item.kind && (
        <span className="shrink-0 text-[11px] font-medium" style={{ color: selected ? notch.secondary : notch.tertiary }}>
          {item.kind}
        </span>
      )}
    </div>
  );
}
