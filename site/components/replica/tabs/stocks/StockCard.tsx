"use client";

import { Minus } from "lucide-react";
import { useId, useLayoutEffect, useRef, useState, type DragEvent } from "react";
import { useL } from "@/components/LangProvider";
import { notch } from "../../style";
import { NumericText } from "./NumericText";
import { absoluteChange, change, price, sessionLength, type Listing, type Quote } from "./market";

/** Green up, red down, grey when the day is flat (StockQuote.Direction.tint). */
export function tint(direction: Quote["direction"]): string {
  return direction === "up" ? notch.good : direction === "down" ? notch.critical : notch.secondary;
}

/** The same colour at `alpha`, for the pill and the area under the line. */
function faded(color: string, alpha: number): string {
  return color.replace(/^rgb\((.+)\)$/, `rgba($1,${alpha})`);
}

const ease = "cubic-bezier(0.32, 0.72, 0, 1)";

/**
 * One ticker on the list, as StockRow: ticker and company, today's line, price and the
 * day's change, and on hover a − to take it off. Drag it onto another card to move it
 * there. `leaving` fades it out before the list drops it; a change of place glides.
 */
export function StockCard({
  item,
  quote,
  hovered,
  leaving,
  animated,
  onRemove,
  onMove,
}: {
  item: Listing;
  quote: Quote;
  /** The script's hover, so the − shows without a pointer. */
  hovered: boolean;
  leaving: boolean;
  animated: boolean;
  onRemove: () => void;
  onMove: (dragged: string) => void;
}) {
  const l = useL();
  const card = useRef<HTMLDivElement>(null);
  const place = useRef<{ x: number; y: number } | null>(null);
  const [targeted, setTargeted] = useState(false);

  // Cards reflow as the list changes; slide from the old place instead of jumping.
  useLayoutEffect(() => {
    const element = card.current;
    if (!element) return;
    const now = { x: element.offsetLeft, y: element.offsetTop };
    const before = place.current;
    place.current = now;
    if (!animated || !before || (before.x === now.x && before.y === now.y)) return;
    element.animate([{ translate: `${before.x - now.x}px ${before.y - now.y}px` }, { translate: "0 0" }], { duration: 250, easing: ease });
  });

  const color = tint(quote.direction);
  const shownPrice = price(quote.price, item.currency, l.lang);
  const shownChange = change(quote.change, l.lang);
  const previous = price(quote.previousClose, item.currency, l.lang);
  const moved = absoluteChange(quote.price - quote.previousClose, l.lang);

  const drop = (event: DragEvent) => {
    event.preventDefault();
    setTargeted(false);
    const dragged = event.dataTransfer.getData("text/plain");
    if (dragged && dragged !== item.symbol) onMove(dragged);
  };

  return (
    <div
      ref={card}
      draggable={!leaving}
      onDragStart={(event) => {
        event.dataTransfer.setData("text/plain", item.symbol);
        event.dataTransfer.effectAllowed = "move";
      }}
      onDragOver={(event) => {
        event.preventDefault();
        setTargeted(true);
      }}
      onDragLeave={() => setTargeted(false)}
      onDrop={drop}
      title={l(`${item.name} · Fechamento anterior ${previous} · ${moved} hoje`, `${item.name} · Previous close ${previous} · ${moved} today`)}
      aria-label={`${item.symbol}, ${item.name}, ${shownPrice}, ${shownChange}`}
      role="group"
      data-hovered={hovered || undefined}
      data-leaving={leaving || undefined}
      className="group relative flex h-11 scale-100 items-center gap-2.5 rounded-[10px] bg-white/[0.045] pl-2.5 pr-1.5 opacity-100 transition-[background-color,opacity,scale] duration-[250ms] starting:scale-[0.96] starting:opacity-0 hover:bg-white/[0.06] data-hovered:bg-white/[0.06] data-leaving:pointer-events-none data-leaving:scale-[0.96] data-leaving:opacity-0 motion-reduce:transition-none"
      style={{ transitionTimingFunction: ease }}
    >
      <span
        aria-hidden
        className="pointer-events-none absolute inset-0 rounded-[10px] border transition-[border-color] duration-150"
        style={{ borderColor: targeted ? "rgba(255,255,255,0.35)" : notch.cardStroke }}
      />
      <div className="flex min-w-0 flex-1 flex-col gap-px">
        <span className="text-[13px] font-semibold leading-4">{item.symbol}</span>
        <span className="truncate text-[10.5px] leading-[13px]" style={{ color: notch.secondary }}>{item.name}</span>
      </div>
      <Sparkline quote={quote} />
      <div className="flex shrink-0 flex-col items-end gap-0.5">
        <span className="text-[12.5px] font-semibold leading-[15px]">
          <NumericText value={shownPrice} animated={animated} />
        </span>
        <span
          className="rounded-full px-1.5 py-[1.5px] text-[10.5px] font-semibold leading-[13px] transition-[background-color,color] duration-300"
          style={{ color, background: quote.direction === "flat" ? notch.control : faded(color, 0.16) }}
        >
          <NumericText value={shownChange} animated={animated} />
        </span>
      </div>
      <button
        type="button"
        onClick={onRemove}
        aria-label={l(`Remover ${item.symbol} da lista`, `Remove ${item.symbol} from list`)}
        title={l("Remover da lista", "Remove from list")}
        className="flex size-[18px] shrink-0 items-center justify-center rounded-full opacity-0 transition-opacity duration-150 group-hover:opacity-100 group-data-hovered:opacity-100 focus-visible:opacity-100"
        style={{ background: notch.controlHover }}
      >
        <Minus size={12} strokeWidth={2.6} aria-hidden />
      </button>
    </div>
  );
}

/**
 * Today's line across the whole session, so a morning chart stops partway, over a
 * dotted line at the previous close (StockSparkline). 60 × 24, line 1.25.
 */
function Sparkline({ quote }: { quote: Quote }) {
  const width = 60;
  const height = 24;
  const inset = 1.25;
  const gradient = `spark${useId().replace(/[^a-zA-Z0-9]/g, "")}`;
  const color = tint(quote.direction);
  const low = Math.min(quote.previousClose, ...quote.closes);
  const high = Math.max(quote.previousClose, ...quote.closes);
  const span = high - low;
  const y = (value: number) => round(inset + (1 - (span > 0 ? (value - low) / span : 0.5)) * (height - inset * 2));
  const x = (index: number) => round((index / (sessionLength - 1)) * width);
  const points = quote.closes.map((value, index) => `${x(index)} ${y(value)}`);
  const line = `M${points.join(" L")}`;
  const lastX = x(quote.closes.length - 1);
  const area = `${line} L${lastX} ${height} L0 ${height} Z`;
  const baseline = y(quote.previousClose);

  return (
    <svg aria-hidden width={width} height={height} viewBox={`0 0 ${width} ${height}`} className="shrink-0 overflow-visible">
      <defs>
        <linearGradient id={gradient} x1="0" y1="0" x2="0" y2={height} gradientUnits="userSpaceOnUse">
          <stop offset="0" stopColor={color} stopOpacity={0.22} />
          <stop offset="1" stopColor={color} stopOpacity={0} />
        </linearGradient>
      </defs>
      <line x1={0} x2={width} y1={baseline} y2={baseline} stroke={notch.tertiary} strokeWidth={1} strokeDasharray="1.5 2.5" />
      {quote.closes.length > 1 && (
        <>
          <path d={area} fill={`url(#${gradient})`} />
          <path d={line} fill="none" stroke={color} strokeWidth={1.25} strokeLinecap="round" strokeLinejoin="round" className="transition-[stroke] duration-300" />
        </>
      )}
    </svg>
  );
}

function round(value: number): number {
  return Math.round(value * 100) / 100;
}
