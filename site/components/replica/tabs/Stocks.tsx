"use client";

import { ChartLine, CircleAlert, Moon, Plus, Search } from "lucide-react";
import { useEffect, useRef, useState, type KeyboardEvent, type ReactNode, type RefObject } from "react";
import { usePlayingInterval, useDemo, useSteps } from "../DemoContext";
import { notch } from "../style";
import {
  defaultWatchlist,
  firstDay,
  listing,
  lookup,
  marketDay,
  maximumCount,
  quote,
  search,
  sessionLength,
  type Listing,
  type Market,
} from "./stocks/market";
import { ClearGlyph, SearchHit, Spinner } from "./stocks/SearchParts";
import { StockCard } from "./stocks/StockCard";
import { usePresence } from "./stocks/usePresence";

/**
 * The scripted loop: the market ticking, a ticker typed letter by letter, its hit
 * picked and added, then hovered and taken off again, the session running to the
 * close, "Mercado fechado", and the next day opening.
 * 0 ticking · 1–5 letters · 6 hits · 7 adding · 8 added · 9 hover · 10 removed · 11 closed
 */
const script = [3200, 160, 160, 160, 750, 160, 1700, 450, 3000, 1300, 11000, 4200] as const;
const words = ["VALE3", "MSFT"] as const;
/** One five-minute bar per tick. */
const tickMs = 1100;
/** Where the session stands when the loop starts, so it reaches the close with the script. */
const opening = sessionLength - Math.round(script.slice(0, 11).reduce((sum, ms) => sum + ms, 0) / tickMs);

type Visitor = { symbols: string[]; query: string };

/**
 * Ações, as NotchStocksTab lays it out: the ticker search with a + on top and the
 * market's status on the right, then the watchlist as cards, two to a row. Typing swaps
 * the list for the hits; ↑ ↓ move, Return adds, Esc goes back. Prices tick only while
 * the demo plays; the visitor's own list takes over the moment they type or click.
 */
export function StocksTab() {
  const { reduced } = useDemo();
  const [step] = useSteps(script);
  const [market, setMarket] = useState<Market>(firstDay);
  const [revealed, setRevealed] = useState(opening);
  const [loop, setLoop] = useState(0);
  const [visitor, setVisitor] = useState<Visitor | null>(null);
  const [adding, setAdding] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [cursor, setCursor] = useState({ query: "", index: 0 });
  const scroller = useRef<HTMLDivElement>(null);
  const lastStep = useRef(step);
  const animated = !reduced;

  // The script, as state derived from the step; the visitor's state replaces it for good.
  const word = words[loop % words.length] ?? words[0];
  const scripted = !visitor && !reduced;
  const scriptedQuery = step >= 1 && step <= 5 ? word.slice(0, step) : step === 6 || step === 7 ? word : "";
  const symbols = visitor?.symbols ?? (scripted && (step === 8 || step === 9) ? [...defaultWatchlist, word] : [...defaultWatchlist]);
  const query = visitor?.query ?? (scripted ? scriptedQuery : "");
  const shownAdding = scripted ? (step === 7 ? word : null) : adding;
  const bars = reduced || (scripted && step === 11) ? sessionLength : revealed;
  const closed = bars >= sessionLength;

  // A new loop opens the next day, from yesterday's closes.
  useEffect(() => {
    const previous = lastStep.current;
    lastStep.current = step;
    if (!scripted || step !== 0 || previous === 0) return;
    setLoop((value) => value + 1);
    setMarket((current) => marketDay(current.day + 1, current));
    setRevealed(opening);
  }, [scripted, step]);

  usePlayingInterval(() => {
    if (!closed) setRevealed((value) => Math.min(value + 1, sessionLength));
  }, tickMs);

  const settled = useSettled(query, 280);
  const searching = query.trim().length > 0;
  const waiting = searching && settled !== query;
  const hits = searching && !waiting ? search(settled) : [];
  const selection = cursor.query === settled ? Math.min(cursor.index, Math.max(hits.length - 1, 0)) : 0;

  useEffect(() => {
    if (!notice) return;
    const timer = window.setTimeout(() => setNotice(null), 4000);
    return () => window.clearTimeout(timer);
  }, [notice]);

  /** Hands the tab to the visitor, keeping what's on screen right now. */
  const take = (): Visitor => {
    const current = visitor ?? { symbols, query };
    if (!visitor) {
      setVisitor(current);
      setRevealed(bars);
    }
    return current;
  };

  const type = (text: string) => {
    take();
    setNotice(null);
    setVisitor((current) => ({ symbols: current?.symbols ?? symbols, query: text }));
  };

  const add = (symbol: string) => {
    const current = take();
    if (adding) return;
    if (current.symbols.includes(symbol)) return setNotice(`${symbol} já está na lista`);
    if (current.symbols.length >= maximumCount) return setNotice(`A lista já tem ${maximumCount} ações`);
    setAdding(symbol);
    window.setTimeout(() => {
      setAdding(null);
      if (!listing(symbol)) return setNotice(`Não encontrei ${symbol}`);
      setVisitor((state) => (state && !state.symbols.includes(symbol) ? { symbols: [...state.symbols, symbol], query: "" } : state));
    }, 450);
  };

  const addCurrent = () => {
    if (!searching) return;
    const hit = hits[selection];
    if (hit) return add(hit.symbol);
    const typed = lookup(query);
    if (typed) return add(typed);
    take();
    setNotice("Código inválido");
  };

  const remove = (symbol: string) => {
    take();
    setVisitor((state) => (state ? { ...state, symbols: state.symbols.filter((item) => item !== symbol) } : state));
  };

  const move = (dragged: string, target: string) => {
    take();
    setVisitor((state) => {
      if (!state) return state;
      const from = state.symbols.indexOf(dragged);
      const to = state.symbols.indexOf(target);
      if (from < 0 || to < 0) return state;
      const next = state.symbols.filter((item) => item !== dragged);
      next.splice(to, 0, dragged);
      return { ...state, symbols: next };
    });
  };

  const keys = (event: KeyboardEvent<HTMLInputElement>) => {
    if (event.key === "Enter") {
      event.preventDefault();
      addCurrent();
    } else if (event.key === "Escape" && query) {
      event.preventDefault();
      type("");
    } else if ((event.key === "ArrowDown" || event.key === "ArrowUp") && hits.length > 0) {
      event.preventDefault();
      const index = Math.min(Math.max(selection + (event.key === "ArrowDown" ? 1 : -1), 0), hits.length - 1);
      setCursor({ query: settled, index });
    }
  };

  const drawn = usePresence(symbols, 250);

  // Show a card that just joined the bottom of the list; go back up once it's gone.
  const count = symbols.length;
  const lastCount = useRef(count);
  useEffect(() => {
    const element = scroller.current;
    const grew = count > lastCount.current;
    lastCount.current = count;
    if (!element) return;
    const behavior = animated ? "smooth" : "auto";
    if (grew) element.scrollTo({ top: element.scrollHeight, behavior });
    else if (scripted && step === 10) element.scrollTo({ top: 0, behavior });
  }, [animated, count, scripted, step]);

  return (
    <div className="flex h-full flex-col gap-2.5 pt-1">
      <div className="flex h-[26px] shrink-0 items-center gap-1.5">
        <label
          className="flex h-[26px] w-[230px] items-center gap-1.5 rounded-[7px] border border-white/[0.18] px-[9px] transition-[border-color] duration-150 focus-within:border-white/[0.28]"
        >
          <Search size={12.5} strokeWidth={2} className="shrink-0" style={{ color: notch.tertiary }} aria-hidden />
          <input
            value={query}
            onChange={(event) => type(event.target.value)}
            onKeyDown={keys}
            placeholder="Buscar código ou empresa"
            aria-label="Buscar código ou empresa"
            spellCheck={false}
            autoComplete="off"
            className="h-full min-w-0 flex-1 bg-transparent text-[12px] text-white outline-none placeholder:text-white/[0.32]"
          />
          {waiting ? (
            <Spinner size={11} />
          ) : (
            query && (
              <button type="button" onClick={() => type("")} aria-label="Limpar a busca" title="Limpar" className="shrink-0 text-white/[0.32] transition-[color] duration-150 hover:text-white/55">
                <ClearGlyph size={11} />
              </button>
            )
          )}
        </label>
        <button
          type="button"
          onClick={addCurrent}
          disabled={!searching || shownAdding !== null}
          aria-label="Adicionar à lista"
          title="Adicionar à lista"
          className="flex size-[26px] shrink-0 items-center justify-center rounded-[7px] bg-white/10 text-white transition-[background-color,opacity,scale] duration-150 hover:bg-white/[0.16] active:scale-95 disabled:opacity-40 disabled:hover:bg-white/10"
        >
          {shownAdding ? <Spinner size={11} /> : <Plus size={16} strokeWidth={1.7} aria-hidden />}
        </button>
        <span className="min-w-3 flex-1" />
        <Status notice={notice} closed={closed} />
      </div>

      <div className="relative min-h-0 flex-1">
        {searching ? (
          <SearchResults
            key="search"
            hits={hits}
            waiting={waiting}
            query={settled}
            selection={selection}
            symbols={symbols}
            adding={shownAdding}
            onPick={add}
          />
        ) : symbols.length === 0 && drawn.length === 0 ? (
          <Empty />
        ) : (
          <Watchlist scroller={scroller} signature={drawn.map((item) => item.key).join("|")}>
            {drawn.map(({ key, leaving }) => {
              const item = listing(key);
              const day = market.days[key];
              if (!item || !day) return null;
              return (
                <StockCard
                  key={key}
                  item={item}
                  quote={quote(day, bars)}
                  hovered={scripted && step === 9 && key === word}
                  leaving={leaving}
                  animated={animated}
                  onRemove={() => remove(key)}
                  onMove={(dragged) => move(dragged, key)}
                />
              );
            })}
          </Watchlist>
        )}
      </div>
    </div>
  );
}

/** `value` once it has held still for `ms`: one search per pause in typing, not per letter. */
function useSettled(value: string, ms: number): string {
  const [settled, setSettled] = useState(value);
  useEffect(() => {
    const timer = window.setTimeout(() => setSettled(value), value.trim() ? ms : 0);
    return () => window.clearTimeout(timer);
  }, [ms, value]);
  return settled;
}

/** Quiet, on the right: what went wrong with the last add, otherwise whether the market is open. */
function Status({ notice, closed }: { notice: string | null; closed: boolean }) {
  if (notice) {
    return (
      <span role="status" className="flex shrink-0 items-center gap-1.5 text-[13px] starting:opacity-0 transition-opacity duration-200" style={{ color: notch.warning }}>
        <CircleAlert size={13} strokeWidth={2} aria-hidden />
        {notice}
      </span>
    );
  }
  if (!closed) return <span role="status" />;
  return (
    <span role="status" className="flex shrink-0 items-center gap-[5px] text-[13px] starting:opacity-0 transition-opacity duration-300" style={{ color: notch.tertiary }}>
      <Moon size={10} fill="currentColor" strokeWidth={0} aria-hidden />
      Mercado fechado
    </span>
  );
}

/** The cards in a scroller with no bar, fading at an edge only when there's more past it. */
function Watchlist({ scroller, signature, children }: { scroller: RefObject<HTMLDivElement | null>; signature: string; children: ReactNode }) {
  const [edges, setEdges] = useState({ top: false, bottom: false });
  const measure = () => {
    const element = scroller.current;
    if (!element) return;
    const top = element.scrollTop > 1;
    const bottom = element.scrollTop + element.clientHeight < element.scrollHeight - 1;
    setEdges((current) => (current.top === top && current.bottom === bottom ? current : { top, bottom }));
  };
  useEffect(() => {
    const element = scroller.current;
    if (!element) return;
    const resize = new ResizeObserver(measure);
    resize.observe(element);
    measure();
    return () => resize.disconnect();
    // The list changing is what moves the edges; measure reads the live element.
  }, [scroller, signature]);
  const fade = 22;
  const mask = `linear-gradient(to bottom, ${edges.top ? "transparent" : "black"} 0, black ${edges.top ? fade : 0}px, black calc(100% - ${edges.bottom ? fade : 0}px), ${edges.bottom ? "transparent" : "black"} 100%)`;
  return (
    <div
      ref={scroller}
      onScroll={measure}
      data-list={signature}
      className="no-scrollbar h-full overflow-y-auto overscroll-contain starting:opacity-0 transition-opacity duration-200"
      style={{ maskImage: mask, WebkitMaskImage: mask }}
    >
      <div className="grid grid-cols-[repeat(auto-fill,minmax(270px,1fr))] gap-x-2 gap-y-1.5 pb-1">{children}</div>
    </div>
  );
}

function SearchResults({
  hits,
  waiting,
  query,
  selection,
  symbols,
  adding,
  onPick,
}: {
  hits: Listing[];
  waiting: boolean;
  query: string;
  selection: number;
  symbols: readonly string[];
  adding: string | null;
  onPick: (symbol: string) => void;
}) {
  if (hits.length === 0) {
    const typed = lookup(query);
    const hint = waiting ? "Buscando…" : typed ? `Nada encontrado. Return tenta ${typed} direto.` : "Nada encontrado com esse nome.";
    return (
      <p aria-live="polite" className="pl-0.5 text-[10.5px] starting:opacity-0 transition-opacity duration-200" style={{ color: notch.tertiary }}>
        {hint}
      </p>
    );
  }
  return (
    <div role="group" aria-label="Resultados da busca" className="grid grid-cols-2 gap-x-1 gap-y-0.5 starting:opacity-0 transition-opacity duration-200">
      {hits.map((item, index) => (
        <SearchHit
          key={item.symbol}
          item={item}
          selected={index === selection}
          listed={symbols.includes(item.symbol)}
          adding={adding === item.symbol}
          onPick={() => onPick(item.symbol)}
        />
      ))}
    </div>
  );
}

/** Nothing on the list yet (NotchStocksTab.empty). */
function Empty() {
  return (
    <div className="flex h-full flex-col items-center justify-center gap-1 starting:opacity-0 transition-opacity duration-200">
      <ChartLine size={22} strokeWidth={2} className="mb-1" style={{ color: notch.tertiary }} aria-hidden />
      <p className="text-[13px] font-semibold">Nenhuma ação na lista</p>
      <p className="text-[10.5px]" style={{ color: notch.secondary }}>Busque um código, como PETR4 ou AAPL, e adicione com +.</p>
    </div>
  );
}
