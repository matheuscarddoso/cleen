"use client";

import { Search } from "lucide-react";
import { useCallback, useEffect, useRef, useState, type ReactNode, type RefObject } from "react";
import { useDemo } from "../../DemoContext";
import { notch } from "../../style";

/**
 * Pieces the Emoji and Ícones replicas share, as the app shares them: the outlined
 * search field, the scroll that fades where there's more, the confirmation pill, and
 * the beat clock that times what happens after a word is typed.
 */

/** Lowercased, accent-free, like the app's `fold` ("Coração" → "coracao"). */
export function fold(text: string): string {
  return text.normalize("NFD").replace(/\p{M}/gu, "").toLowerCase();
}

/** The words of a folded text: letters and digits, split on everything else. */
export function words(text: string): string[] {
  return fold(text).split(/[^\p{L}\p{N}]+/u).filter(Boolean);
}

/** Puts text on the clipboard when the browser allows it; a refusal is not an error here. */
export async function copyText(text: string): Promise<void> {
  if (typeof navigator === "undefined" || !navigator.clipboard) return;
  try {
    await navigator.clipboard.writeText(text);
  } catch {
    // Denied (no focus, no permission): the confirmation still shows what the app does.
  }
}

/**
 * Counts through `durations` once `key` is set and the demo plays, starting over each
 * time the key changes. Returns -1 without a key.
 */
export function useBeats(key: string | null, durations: readonly number[]): number {
  const { playing } = useDemo();
  const [beat, setBeat] = useState(0);
  const [seen, setSeen] = useState(key);
  if (seen !== key) {
    setSeen(key);
    setBeat(0);
  }
  useEffect(() => {
    if (key === null || !playing || beat >= durations.length - 1) return;
    const timer = window.setTimeout(() => setBeat((current) => current + 1), durations[beat] ?? 600);
    return () => window.clearTimeout(timer);
  }, [beat, durations, key, playing]);
  return key === null ? -1 : beat;
}

/** The clear button's glyph: SF's xmark.circle.fill, a filled disc with the cross cut out. */
function ClearGlyph() {
  return (
    <svg width="11" height="11" viewBox="0 0 22 22" aria-hidden>
      <circle cx="11" cy="11" r="11" fill={notch.tertiary} />
      <path d="M7.5 7.5l7 7M14.5 7.5l-7 7" stroke="#000" strokeWidth="2.2" strokeLinecap="round" />
    </svg>
  );
}

/**
 * The tab's search: 200 × 26, a hairline outline, magnifier, the field and a clear
 * button once there's text. While the script types, a steady caret follows the text.
 */
export function SearchField({
  value,
  placeholder,
  caret,
  onChange,
  onSubmit,
}: {
  value: string;
  placeholder: string;
  /** Show the scripted caret (the real one appears once the visitor focuses the field). */
  caret: boolean;
  onChange: (value: string) => void;
  onSubmit: () => void;
}) {
  return (
    <label
      className="relative flex h-[26px] w-[200px] shrink-0 items-center gap-1.5 rounded-[7px] px-[9px]"
      style={{ boxShadow: "inset 0 0 0 1px rgba(255,255,255,0.18)" }}
    >
      <Search size={11} strokeWidth={2.2} className="shrink-0" style={{ color: notch.tertiary }} aria-hidden />
      <span className="relative min-w-0 flex-1">
        <input
          type="search"
          value={value}
          onChange={(event) => onChange(event.target.value)}
          onKeyDown={(event) => {
            if (event.key === "Enter") {
              event.preventDefault();
              onSubmit();
            }
          }}
          placeholder={placeholder}
          aria-label={placeholder}
          autoComplete="off"
          spellCheck={false}
          className="w-full appearance-none bg-transparent text-[12px] text-white outline-none placeholder:text-white/45 [&::-webkit-search-cancel-button]:appearance-none"
        />
        {caret && (
          <span aria-hidden className="pointer-events-none absolute inset-y-0 left-0 flex items-center whitespace-pre text-[12px] text-transparent">
            {value}
            {/* Before the placeholder when empty, a hair after the last letter otherwise. */}
            <span className={`h-[14px] w-[1.5px] rounded-full bg-white ${value ? "ml-[1.5px]" : "-ml-[1.5px]"}`} />
          </span>
        )}
      </span>
      {value.length > 0 && (
        <button type="button" onClick={() => onChange("")} aria-label="Limpar busca" title="Limpar busca" className="flex shrink-0 items-center">
          <ClearGlyph />
        </button>
      )}
    </label>
  );
}

/** The eased stops of the app's fade mask (ScrollEdgeFade), over `length` points. */
function fadeStops(length: number, top: boolean, bottom: boolean): string {
  const curve: [number, number][] = [
    [0, 0],
    [0.25, 0.12],
    [0.5, 0.4],
    [0.75, 0.75],
    [1, 1],
  ];
  const head = top ? curve.map(([at, alpha]) => `rgba(0,0,0,${alpha}) ${at * length}px`) : ["#000 0px"];
  const tail = bottom ? [...curve].reverse().map(([at, alpha]) => `rgba(0,0,0,${alpha}) calc(100% - ${at * length}px)`) : ["#000 100%"];
  return `linear-gradient(to bottom, ${[...head, ...tail].join(", ")})`;
}

/**
 * NotchScroll: fills the room, no scrollbar, and the edges dissolve (fade plus a light
 * blur) only where there's more to see.
 */
export function FadeScroll({ children, scrollRef, length = 22 }: { children: ReactNode; scrollRef?: RefObject<HTMLDivElement | null>; length?: number }) {
  const own = useRef<HTMLDivElement>(null);
  const box = scrollRef ?? own;
  const [edges, setEdges] = useState({ top: false, bottom: false });
  const measure = useCallback(() => {
    const element = box.current;
    if (!element) return;
    const next = { top: element.scrollTop > 1, bottom: element.scrollTop + element.clientHeight < element.scrollHeight - 1 };
    setEdges((current) => (current.top === next.top && current.bottom === next.bottom ? current : next));
  }, [box]);
  useEffect(() => {
    const element = box.current;
    if (!element) return;
    const resize = new ResizeObserver(measure);
    resize.observe(element);
    if (element.firstElementChild) resize.observe(element.firstElementChild);
    measure();
    return () => resize.disconnect();
  }, [box, measure]);
  const mask = fadeStops(length, edges.top, edges.bottom);
  return (
    <div className="relative min-h-0 flex-1">
      <div
        ref={box}
        onScroll={measure}
        className="h-full overflow-y-auto overscroll-contain [scrollbar-width:none] [&::-webkit-scrollbar]:hidden"
        style={{ maskImage: mask, WebkitMaskImage: mask }}
      >
        <div>{children}</div>
      </div>
      {(["top", "bottom"] as const).map((edge) => (
        <div
          key={edge}
          aria-hidden
          className="pointer-events-none absolute inset-x-0 transition-opacity duration-200"
          style={{
            [edge]: 0,
            height: length,
            opacity: edges[edge] ? 1 : 0,
            backdropFilter: "blur(5px)",
            WebkitBackdropFilter: "blur(5px)",
            maskImage: `linear-gradient(to ${edge}, transparent, rgba(0,0,0,0.55) 55%, #000)`,
            WebkitMaskImage: `linear-gradient(to ${edge}, transparent, rgba(0,0,0,0.55) 55%, #000)`,
          }}
        />
      ))}
    </div>
  );
}

/**
 * The small pill that confirms a pick, rising from the bottom edge: opaque black under
 * the lift so the grid doesn't show through. Keeps its last content while it fades.
 */
export function ConfirmationPill({ shown, live, children }: { shown: boolean; /** Announce it: the visitor's own picks only, never the script's. */ live: boolean; children: ReactNode }) {
  const [last, setLast] = useState<ReactNode>(children);
  if (shown && children !== last) setLast(children);
  return (
    <div aria-live={live ? "polite" : "off"} className="pointer-events-none absolute inset-x-0 bottom-1.5 z-10 flex justify-center">
      <div
        className="flex h-7 items-center gap-1.5 rounded-full px-3 text-[11.5px] font-medium text-white transition-[opacity,scale,translate] duration-300"
        style={{
          background: `linear-gradient(${notch.selection}, ${notch.selection}), #000`,
          boxShadow: `inset 0 0 0 1px ${notch.cardStroke}`,
          opacity: shown ? 1 : 0,
          scale: shown ? "1" : "0.92",
          translate: shown ? "0 0" : "0 4px",
          transitionTimingFunction: "cubic-bezier(0.32, 0.72, 0, 1)",
        }}
      >
        {shown ? children : last}
      </div>
    </div>
  );
}

/** A confirmation the visitor caused: what it says, shown for `ms` then hidden. */
export function useConfirmation<T>(ms = 1200) {
  const [shown, setShown] = useState<{ value: T; stamp: number } | null>(null);
  useEffect(() => {
    if (!shown) return;
    const timer = window.setTimeout(() => setShown(null), ms);
    return () => window.clearTimeout(timer);
  }, [ms, shown]);
  const show = useCallback((value: T) => setShown({ value, stamp: Date.now() }), []);
  return [shown?.value ?? null, show] as const;
}
