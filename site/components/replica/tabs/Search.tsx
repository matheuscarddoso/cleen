"use client";

import { CircleCheck, Search } from "lucide-react";
import { useEffect, useId, useMemo, useRef, useState, type KeyboardEvent } from "react";
import { useL } from "@/components/LangProvider";
import type { Lang } from "@/lib/lang";
import { useDemo, usePlayingInterval, useTypewriter } from "../DemoContext";
import { useReplica } from "../ReplicaContext";
import { notch } from "../style";
import { reviewTitle } from "../review";
import { actionsFor, type Action } from "./search/actions";
import { results, type Item } from "./search/catalog";
import { ClearGlyph, ItemGlyph } from "./search/Glyphs";

/**
 * What the script types in each language, and how many times it presses ↓ once each
 * query is in. Both run the same features in the same order.
 */
const script: Record<Lang, readonly string[]> = {
  pt: ["met", "100 usd em brl", "15h em tóquio", "figma", "orçamento", "gh cleen", ";email", "reuni"],
  en: ["left", "100 usd to eur", "3pm in tokyo", "figma", "budget", "gh cleen", ";email", "meeting"],
};
const presses = [2, 0, 0, 0, 0, 0, 0, 1] as const;
/** The query whose result the script opens ⌘K on. */
const actionsQuery = 3;

/**
 * Buscar (⌥Space), as NotchSearchView lays it out: the field, then results grouped by
 * kind. The script types a window command, a currency, a time zone, an open window (and
 * opens its ⌘K actions), a file, a quicklink, a snippet and today's meetings; the visitor
 * can type for real, move with ↑/↓, run with Return, open ⌘K and leave with Esc.
 */
export function SearchView() {
  const { playing, reduced } = useDemo();
  const { setMode, setTab, setReview } = useReplica();
  const l = useL();
  const queries = script[l.lang];
  const typed = useTypewriter(queries, { hold: 2800 });
  const [moves, setMoves] = useState({ index: 0, count: 0 });
  const [manual, setManual] = useState<{ query: string; selection: number } | null>(null);
  const [focused, setFocused] = useState(false);
  const [caret, setCaret] = useState(true);
  const [done, setDone] = useState<string | null>(null);
  const [scrolled, setScrolled] = useState(false);
  /** The ⌘K panel the visitor opened, and its selected action. */
  const [actions, setActions] = useState<number | null>(null);
  const [scriptedActions, setScriptedActions] = useState(false);
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

  // On the open-window query, the script opens ⌘K on it for a moment.
  useEffect(() => {
    setScriptedActions(false);
    if (!playing || !typed.finished || typed.index !== actionsQuery) return;
    const timer = window.setTimeout(() => setScriptedActions(true), 700);
    return () => window.clearTimeout(timer);
  }, [playing, typed.finished, typed.index]);

  usePlayingInterval(() => setCaret((shown) => !shown), 530);

  // Opened from the magnifier: the field takes the keyboard, like ⌥Space. Not on load.
  useEffect(() => {
    if (navigator.userActivation?.isActive) input.current?.focus({ preventScroll: true });
    return () => window.clearTimeout(leave.current);
  }, []);

  // With reduced motion the first query stands typed in, as one still.
  const scriptedQuery = reduced ? (queries[0] ?? "") : typed.text;
  const query = manual?.query ?? scriptedQuery;
  const sections = useMemo(() => results(query, l.lang), [query, l.lang]);
  const items = useMemo(() => sections.flatMap((section) => section.items), [sections]);
  const selection = items.length === 0 ? -1 : Math.min(manual?.selection ?? scriptedMoves, items.length - 1);
  const selected = items[selection];
  const actionList = selected ? actionsFor(selected, l.lang) : [];
  const actionSelection = manual ? actions : scriptedActions ? 0 : null;

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

  const finish = (message: string) => {
    setActions(null);
    setDone(message);
    window.clearTimeout(leave.current);
    leave.current = window.setTimeout(() => setMode("tool"), 1300);
  };

  const run = (item: Item | undefined) => {
    if (!item) return;
    setManual(take());
    const outcome = item.outcome;
    if (outcome.kind === "tab") {
      setTab(outcome.tab);
      setMode("tool");
      return;
    }
    if (outcome.kind === "review") {
      // Deleting asks first, from the launcher too: the review covers it.
      setReview({
        title: reviewTitle(outcome.items.length, outcome.outcome, l.lang),
        outcome: outcome.outcome,
        items: outcome.items,
        onConfirm: () => finish(outcome.message),
        onCancel: () => input.current?.focus({ preventScroll: true }),
      });
      return;
    }
    finish(outcome.message);
  };

  const runAction = (action: Action | undefined) => {
    if (!action) return;
    if (action === actionList[0]) run(selected);
    else finish(action.message);
  };

  const onKeyDown = (event: KeyboardEvent<HTMLInputElement>) => {
    if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "k") {
      event.preventDefault();
      setManual(take());
      setActions(actions === null && selected ? 0 : null);
      return;
    }
    if (actions !== null) {
      // ⌘K's panel has the arrows, Return and Esc while it's open.
      event.preventDefault();
      if (event.key === "ArrowDown") setActions((actions + 1) % actionList.length);
      else if (event.key === "ArrowUp") setActions((actions - 1 + actionList.length) % actionList.length);
      else if (event.key === "Enter") runAction(actionList[actions]);
      else if (event.key === "Escape") setActions(null);
      return;
    }
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
    // Raycast's layout, as the app has it: the field bare on top, a hairline, the list,
    // and a bar of keys at the bottom.
    <div className="flex h-full flex-col">
      <label className="relative flex h-10 shrink-0 items-center gap-2.5 px-5">
        <Search size={15} strokeWidth={2.4} className="shrink-0" style={{ color: notch.secondary }} aria-hidden />
        <span className="relative flex min-w-0 flex-1 items-center">
          <input
            ref={input}
            value={query}
            onChange={(event) => {
              setDone(null);
              setActions(null);
              setManual({ query: event.target.value, selection: 0 });
            }}
            onFocus={() => {
              setFocused(true);
              setManual(take());
            }}
            onBlur={() => setFocused(false)}
            onKeyDown={onKeyDown}
            placeholder={l("Buscar apps, janelas, arquivos, cálculos…", "Search apps, files, windows, commands…")}
            aria-label={l("Buscar apps, janelas, arquivos, cálculos", "Search apps, files, windows, commands")}
            role="combobox"
            aria-expanded={items.length > 0}
            aria-controls={`${id}-results`}
            aria-activedescendant={selected ? `${id}-${selection}` : undefined}
            aria-autocomplete="list"
            autoComplete="off"
            spellCheck={false}
            className="w-full bg-transparent text-[17px] text-white caret-white outline-none placeholder:text-white/30"
            style={{ outline: "none" }}
          />
          {showsCaret && (
            <span aria-hidden className="pointer-events-none absolute left-0 top-1/2 flex -translate-y-1/2 whitespace-pre text-[17px] text-transparent">
              {query}
              <span className="ml-px h-[19px] w-[2px] rounded-full bg-white" />
            </span>
          )}
        </span>
        {query.length > 0 && (
          <button
            type="button"
            aria-label={l("Limpar a busca", "Clear Search")}
            title={l("Limpar a busca", "Clear Search")}
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
      <span aria-hidden className="h-px shrink-0" style={{ background: notch.separator }} />

      {done ? (
        <p role="status" className="flex flex-1 animate-[numeric_300ms_ease-out] items-center justify-center gap-1.5 text-[12px] font-medium">
          <CircleCheck size={14} strokeWidth={2.2} style={{ color: notch.good }} aria-hidden />
          {done}
        </p>
      ) : items.length === 0 ? (
        <p className="flex flex-1 items-center justify-center text-[12px] font-medium" style={{ color: notch.tertiary }}>
          {l("Nada encontrado", "Nothing found")}
        </p>
      ) : (
        <div
          ref={list}
          id={`${id}-results`}
          role="listbox"
          aria-label={l("Resultados", "Results")}
          className="relative min-h-0 flex-1 overflow-y-auto px-2.5 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden"
          onScroll={(event) => setScrolled(event.currentTarget.scrollTop > 0)}
          style={{ maskImage: `linear-gradient(to bottom, ${scrolled ? "transparent, #000 14px" : "#000"}, #000 calc(100% - 14px), transparent)` }}
        >
          <div className="flex flex-col py-0.5">
            {sections.map((section) => (
              <div key={section.title} role="group" aria-label={section.title} className="flex flex-col">
                <span aria-hidden className="px-2.5 pb-[3px] pt-2 text-[11px] font-medium leading-[13px]" style={{ color: notch.tertiary }}>
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
      {actionSelection !== null && selected && !done && (
        <ActionPanel
          item={selected}
          actions={actionList}
          selection={actionSelection}
          onHover={(index) => manual && setActions(index)}
          onRun={(action) => {
            setManual(take());
            runAction(action);
          }}
        />
      )}
      <KeyBar
        action={selected ? actionLabel(selected, l.lang) : null}
        onActions={() => {
          setManual(take());
          setActions(actions === null && selected ? 0 : null);
          input.current?.focus({ preventScroll: true });
        }}
        actionsOpen={actionSelection !== null}
      />
    </div>
  );
}

/** Return's verb for a row, as the app's key bar words it. */
function actionLabel(item: Item, lang: Lang): string {
  const l = (pt: string, en: string) => (lang === "en" ? en : pt);
  const [group] = item.id.split(".");
  if (item.verb) return item.verb;
  // Apps and tabs open; window layouts arrange; Cleen's commands and the Mac's run.
  if (group === "app" || group === "tab" || item.kind === undefined) return l("Abrir", "Open");
  if (group === "window") return l("Ajustar janela", "Arrange Window");
  if (group === "tool" || group === "lorem" || group === "system") return l("Executar", "Run");
  return item.kind;
}

/** The bottom bar (FooterKey): what Return does to the selected row, ⌘K, ↑↓ and Esc. */
function KeyBar({ action, onActions, actionsOpen }: { action: string | null; onActions: () => void; actionsOpen: boolean }) {
  const l = useL();
  const keys: { label: string; keys: string[]; emphasized?: boolean }[] = [
    ...(action ? [{ label: action, keys: ["⏎"], emphasized: true }] : []),
    { label: l("Mover", "Move"), keys: ["↑", "↓"] },
    { label: l("Fechar", "Close"), keys: ["esc"] },
  ];
  return (
    <div className="mb-1.5 flex h-8 shrink-0 items-center justify-end gap-3.5 border-t px-[26px]" style={{ borderColor: notch.separator }}>
      {keys.map((key) => (
        <span key={key.label} aria-hidden className="flex items-center gap-1.5 text-[12px] font-medium" style={{ color: key.emphasized ? notch.primary : notch.secondary }}>
          {key.label}
          <Keys keys={key.keys} />
        </span>
      ))}
      <button
        type="button"
        onClick={onActions}
        aria-expanded={actionsOpen}
        className="-mx-1.5 flex items-center gap-1.5 rounded-[6px] px-1.5 py-0.5 text-[12px] font-medium transition-colors duration-150 hover:bg-white/10"
        style={{ color: actionsOpen ? notch.primary : notch.secondary }}
      >
        {l("Ações", "Actions")}
        <Keys keys={["⌘", "K"]} />
      </button>
    </div>
  );
}

function Keys({ keys }: { keys: readonly string[] }) {
  return (
    <span className="flex gap-[3px]">
      {keys.map((glyph) => (
        <span key={glyph} className="flex h-5 min-w-5 items-center justify-center rounded-[5px] px-1 text-[11px]" style={{ background: notch.control, color: notch.secondary }}>
          {glyph}
        </span>
      ))}
    </span>
  );
}

/**
 * ⌘K, as Raycast has it: the selected row's other actions in a panel over the list's
 * corner, each with its shortcut. The first one is Return's.
 */
function ActionPanel({ item, actions, selection, onHover, onRun }: { item: Item; actions: Action[]; selection: number; onHover: (index: number) => void; onRun: (action: Action) => void }) {
  const l = useL();
  return (
    <div
      role="menu"
      aria-label={l(`Ações de ${item.title}`, `Actions for ${item.title}`)}
      className="absolute bottom-[46px] right-3 z-10 w-[272px] origin-bottom-right animate-[actions_180ms_cubic-bezier(0.2,0,0,1)] overflow-hidden rounded-[12px] p-1 shadow-[0_18px_40px_rgba(0,0,0,0.6)]"
      style={{ background: "rgb(30,30,32)", boxShadow: "inset 0 0 0 1px rgba(255,255,255,0.1), 0 18px 40px rgba(0,0,0,0.6)" }}
    >
      <span className="block truncate px-2 pb-1 pt-1.5 text-[11px] font-medium" style={{ color: notch.tertiary }}>
        {item.title}
      </span>
      {actions.map((action, index) => (
        <button
          key={action.title}
          type="button"
          role="menuitem"
          onPointerMove={() => onHover(index)}
          onClick={() => onRun(action)}
          className="flex h-7 w-full items-center gap-2 rounded-[7px] px-2 text-left text-[12.5px] font-medium"
          style={{ background: index === selection ? notch.selection : undefined, color: action.destructive ? notch.critical : notch.primary }}
        >
          <span className="min-w-0 flex-1 truncate">{action.title}</span>
          {action.keys && <Keys keys={action.keys} />}
        </button>
      ))}
      <span aria-hidden className="mx-1 mt-1 block h-px" style={{ background: notch.separator }} />
      <span aria-hidden className="block px-2 pb-1 pt-1.5 text-[12px]" style={{ color: notch.tertiary }}>
        {l("Buscar ações…", "Search actions…")}
      </span>
    </div>
  );
}

/** One result (SearchRow): icon, title and subtitle, the kind on the right. */
function Row({ id, index, item, selected, onHover, onRun }: { id: string; index: number; item: Item; selected: boolean; onHover: () => void; onRun: () => void }) {
  const l = useL();
  return (
    <div
      id={id}
      data-index={index}
      role="option"
      aria-selected={selected}
      onPointerMove={onHover}
      onClick={onRun}
      className="flex h-8 shrink-0 cursor-default items-center gap-2.5 rounded-[8px] px-2.5"
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
      {item.alias && (
        <span className="shrink-0 rounded-[5px] px-1.5 text-[11px] font-medium leading-[18px]" style={{ boxShadow: `inset 0 0 0 1px ${notch.separator}`, color: notch.secondary }}>
          {item.alias}
        </span>
      )}
      {item.hotkey && (
        <span className="flex shrink-0 gap-[3px]" aria-label={l(`Atalho ${item.hotkey.join("")}`, `Shortcut ${item.hotkey.join("")}`)}>
          {item.hotkey.map((glyph) => (
            <span key={glyph} className="flex h-[18px] min-w-[18px] items-center justify-center rounded-[4px] px-1 text-[10.5px]" style={{ background: notch.control, color: notch.secondary }}>
              {glyph}
            </span>
          ))}
        </span>
      )}
      {item.kind && (
        <span className="shrink-0 text-[12px]" style={{ color: selected ? notch.secondary : notch.tertiary }}>
          {item.kind}
        </span>
      )}
    </div>
  );
}
