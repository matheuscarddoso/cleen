"use client";

import { Minus, Plus, type LucideIcon } from "lucide-react";
import { Children, cloneElement, isValidElement, useEffect, useRef, useState, type ReactElement, type ReactNode, type Ref } from "react";
import { useL } from "@/components/LangProvider";
import { notch } from "../../style";

/** Height of the app's brightness pill (BrightnessSlider.height). */
const sliderHeight = 24;

/** A collapsible row: in a Group it takes its hairline with it, like a SwiftUI `if`. */
export function Reveal({ shown, children, separator = null }: { shown: boolean; children: ReactNode; separator?: ReactNode }) {
  return (
    <div
      aria-hidden={!shown}
      inert={!shown}
      className="grid transition-[grid-template-rows,opacity] duration-[250ms] ease-[cubic-bezier(0.32,0.72,0,1)]"
      style={{ gridTemplateRows: shown ? "1fr" : "0fr", opacity: shown ? 1 : 0 }}
    >
      <div className="min-h-0 overflow-hidden">
        {separator}
        {children}
      </div>
    </div>
  );
}

/** The card surface with its hairline drawn inside, like strokeBorder: it never shifts the rows. */
export const card = { background: notch.card, boxShadow: `inset 0 0 0 1px ${notch.cardStroke}` } as const;

function Separator() {
  return <div aria-hidden className="ml-9 h-px" style={{ background: notch.separator }} />;
}

/** NotchGroup: one quiet card, rows split by hairlines inset 36 from the left. */
export function Group({ children }: { children: ReactNode }) {
  const rows = Children.toArray(children).filter(isValidElement);
  return (
    <div className="overflow-hidden rounded-[12px]" style={card}>
      {rows.map((row, index) => {
        if (index === 0) return row;
        if (row.type === Reveal) {
          const reveal = row as ReactElement<{ separator?: ReactNode }>;
          return cloneElement(reveal, { separator: <Separator /> });
        }
        return (
          <div key={row.key ?? index}>
            <Separator />
            {row}
          </div>
        );
      })}
    </div>
  );
}

/** SettingRow: the label (and an optional note) on the left, its control on the right. */
export function Row({ title, note, children, anchor }: { title: string; note?: string; children?: ReactNode; anchor?: string }) {
  return (
    <div data-anchor={anchor} className="flex min-h-9 items-center gap-3 px-3 py-[7px]">
      <div className="flex min-w-0 flex-1 flex-col gap-px">
        <span className="text-[12px] font-medium leading-[14px]">{title}</span>
        {note && (
          <span className="text-[10px] leading-[12px] tracking-[0.006em]" style={{ color: notch.tertiary }}>
            {note}
          </span>
        )}
      </div>
      {children && (
        <>
          <span aria-hidden className="w-2 shrink-0" />
          <div className="flex shrink-0 items-center">{children}</div>
        </>
      )}
    </div>
  );
}

/** A small caps heading over a group ("PASTAS DE PROJETOS"), as in the sidebar. */
export function Caps({ children }: { children: ReactNode }) {
  return (
    <p className="pl-1 text-[9.5px] font-semibold uppercase leading-[11px] tracking-[0.6px]" style={{ color: notch.tertiary }}>
      {children}
    </p>
  );
}

/** NotchSegmented: pill segments in a grey capsule, the chosen one white with black text. */
export function Segmented<Value extends string | number | boolean>({
  label,
  options,
  value,
  onChange,
}: {
  label: string;
  options: readonly { label: string; value: Value }[];
  value: Value;
  onChange: (value: Value) => void;
}) {
  return (
    <div role="radiogroup" aria-label={label} className="flex gap-0.5 rounded-full p-0.5" style={{ background: notch.control }}>
      {options.map((option) => {
        const selected = option.value === value;
        return (
          <button
            key={String(option.value)}
            type="button"
            role="radio"
            aria-checked={selected}
            onClick={() => onChange(option.value)}
            className="h-[22px] whitespace-nowrap rounded-full px-[9px] text-[11px] font-medium transition-[background-color,color] duration-[180ms]"
            style={{ background: selected ? "#fff" : "transparent", color: selected ? "#000" : "rgba(255,255,255,0.75)" }}
          >
            {option.label}
          </button>
        );
      })}
    </div>
  );
}

/**
 * NotchSwitch: the mini macOS switch, drawn the way the notch shows it (the panel never
 * activates the app, so the track stays the inactive grey): a 36 × 16 track, a 21 × 13 pill knob.
 */
export function Switch({ label, on, onChange, disabled = false }: { label: string; on: boolean; onChange: (on: boolean) => void; disabled?: boolean }) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={on}
      aria-label={label}
      disabled={disabled}
      onClick={() => onChange(!on)}
      className="relative h-4 w-9 shrink-0 rounded-full transition-[background-color,opacity] duration-200 disabled:opacity-40"
      style={{ background: on ? "rgba(255,255,255,0.17)" : "rgba(255,255,255,0.1)", boxShadow: "inset 0 0 0 0.5px rgba(255,255,255,0.06)" }}
    >
      <span
        aria-hidden
        className="absolute left-[1.5px] top-[1.5px] h-[13px] w-[21px] rounded-full bg-[#e0e0e0] shadow-[0_0.5px_1.5px_rgba(0,0,0,0.45)] transition-transform duration-200 ease-[cubic-bezier(0.32,0.72,0,1)]"
        style={{ transform: on ? "translateX(12px)" : "translateX(0)" }}
      />
    </button>
  );
}

function StepButton({ icon: Icon, label, disabled, onClick }: { icon: LucideIcon; label: string; disabled: boolean; onClick: () => void }) {
  return (
    <button type="button" aria-label={label} disabled={disabled} onClick={onClick} className="flex h-6 w-[26px] items-center justify-center transition-opacity duration-150 disabled:opacity-30">
      <Icon size={10} strokeWidth={3} aria-hidden />
    </button>
  );
}

/** NotchStepper / NotchChoiceStepper: − value + in one pill, moving through `choices`. */
export function Stepper<Value extends number>({
  label,
  choices,
  value,
  onChange,
  format,
  minWidth = 52,
  disabled = false,
}: {
  label: string;
  choices: readonly Value[];
  value: Value;
  onChange: (value: Value) => void;
  format: (value: Value) => string;
  minWidth?: number;
  disabled?: boolean;
}) {
  const l = useL();
  const index = Math.max(0, choices.indexOf(value));
  return (
    <div role="group" aria-label={label} className="flex h-6 items-center rounded-full transition-opacity duration-200" style={{ background: notch.control, opacity: disabled ? 0.4 : 1 }}>
      <StepButton icon={Minus} label={l("Diminuir", "Decrease")} disabled={disabled || index === 0} onClick={() => onChange(choices[Math.max(0, index - 1)] ?? value)} />
      <span aria-live="polite" className="text-center text-[11px] font-semibold tabular-nums" style={{ minWidth }}>
        {format(value)}
      </span>
      <StepButton icon={Plus} label={l("Aumentar", "Increase")} disabled={disabled || index === choices.length - 1} onClick={() => onChange(choices[Math.min(choices.length - 1, index + 1)] ?? value)} />
    </div>
  );
}

/** A shortcut shown as a key cap (GeneralSettings: 11 pt semibold on a grey 22 pt tile). */
export function Keycap({ children }: { children: ReactNode }) {
  return (
    <span className="flex h-[22px] items-center whitespace-nowrap rounded-[6px] px-2 text-[11px] font-semibold" style={{ background: notch.control }}>
      {children}
    </span>
  );
}

/** NotchPillButtonStyle: white pill with black text, grey pill, or the red one confirming. */
export function Pill({ kind = "primary", children, onClick, disabled = false }: { kind?: "primary" | "secondary" | "destructive"; children: ReactNode; onClick?: () => void; disabled?: boolean }) {
  const look = {
    primary: "bg-white text-black hover:bg-white/90 active:bg-white/80",
    secondary: "bg-white/10 text-white hover:bg-white/[0.16] active:bg-white/[0.16]",
    destructive: "bg-[rgb(255,84,84)] text-white active:bg-[rgb(255,84,84)]/80",
  }[kind];
  return (
    <button
      type="button"
      disabled={disabled}
      onClick={onClick}
      className={`h-[26px] whitespace-nowrap rounded-full px-3 text-[12px] font-medium transition-[background-color,scale,opacity] duration-150 active:scale-[0.97] disabled:opacity-40 ${look}`}
    >
      {children}
    </button>
  );
}

/** NotchIconButton: a grey glyph that lights up on hover. */
export function GlyphButton({ icon: Icon, label, onClick }: { icon: LucideIcon; label: string; onClick?: () => void }) {
  return (
    <button
      type="button"
      aria-label={label}
      title={label}
      onClick={onClick}
      className="flex h-6 w-[26px] items-center justify-center rounded-[7px] text-white/55 transition-colors duration-150 hover:bg-white/10 hover:text-white"
    >
      <Icon size={13} strokeWidth={2} aria-hidden />
    </button>
  );
}

/** sun.max.fill / sun.min.fill: a solid sun, long rays when bright, dots when dim. */
function SunGlyph({ full }: { full: boolean }) {
  return (
    <svg viewBox="0 0 24 24" width={13} height={13} fill="currentColor" aria-hidden>
      <circle cx="12" cy="12" r={full ? 4.2 : 4.6} />
      {Array.from({ length: 8 }, (_, ray) => {
        const angle = (ray * Math.PI) / 4;
        const [inner, outer] = full ? [7, 10] : [8.4, 8.6];
        return (
          <line
            key={ray}
            x1={12 + Math.cos(angle) * inner}
            y1={12 + Math.sin(angle) * inner}
            x2={12 + Math.cos(angle) * outer}
            y2={12 + Math.sin(angle) * outer}
            stroke="currentColor"
            strokeWidth={full ? 2.2 : 2.6}
            strokeLinecap="round"
          />
        );
      })}
    </svg>
  );
}

/**
 * BrightnessSlider: Control Center's pill, filling white from the left with the sun in
 * it. Pointer drags map like the app (the knob's half-width off each end); the hidden
 * range input underneath carries the keyboard and the screen reader.
 */
export function BrightnessSlider({ label, value, onChange, width = 200, gliding = false }: { label: string; value: number; onChange: (value: number) => void; width?: number; gliding?: boolean }) {
  const box = useRef<HTMLDivElement>(null);
  const fraction = Math.min(1, Math.max(0, value));
  const filled = sliderHeight + (width - sliderHeight) * fraction;

  const fromPointer = (clientX: number) => {
    const element = box.current;
    if (!element) return;
    const rect = element.getBoundingClientRect();
    // The demo canvas is scaled to fit its frame: undo that to get design pixels.
    const scale = rect.width / element.offsetWidth || 1;
    const x = (clientX - rect.left) / scale;
    onChange(Math.min(1, Math.max(0, (x - sliderHeight / 2) / (width - sliderHeight))));
  };

  return (
    <div
      ref={box}
      className="relative shrink-0 cursor-pointer touch-none rounded-full has-[:focus-visible]:outline-2 has-[:focus-visible]:outline-offset-2 has-[:focus-visible]:outline-[#0071e3]"
      style={{ width, height: sliderHeight, background: notch.control }}
      onPointerDown={(event) => {
        event.currentTarget.setPointerCapture(event.pointerId);
        fromPointer(event.clientX);
      }}
      onPointerMove={(event) => {
        if (event.currentTarget.hasPointerCapture(event.pointerId)) fromPointer(event.clientX);
      }}
    >
      <div
        aria-hidden
        className="absolute inset-y-0 left-0 rounded-full"
        style={{ width: filled, background: "rgba(255,255,255,0.88)", transition: gliding ? "none" : "width 120ms cubic-bezier(0.32,0.72,0,1)" }}
      />
      <span aria-hidden className="absolute inset-y-0 left-0 flex w-6 items-center justify-center" style={{ color: "rgba(0,0,0,0.55)" }}>
        <SunGlyph full={fraction >= 0.5} />
      </span>
      <input
        type="range"
        min={0}
        max={1}
        step={0.01}
        value={fraction}
        aria-label={label}
        aria-valuetext={`${Math.round(fraction * 100)}%`}
        onChange={(event) => onChange(Number(event.target.value))}
        className="pointer-events-none absolute inset-0 h-full w-full opacity-0"
      />
    </div>
  );
}

const fadeLength = 22;

/** The ease-out ramp ScrollEdgeFade uses, so the fade reads as gradual, not a band. */
function ramp(edge: "top" | "bottom") {
  const curve = [0, 0.12, 0.4, 0.75, 1];
  return curve
    .map((alpha, index) => {
      const at = (index / 4) * fadeLength;
      return `rgba(0,0,0,${alpha}) ${edge === "top" ? `${at}px` : `calc(100% - ${at}px)`}`;
    })
    .join(", ");
}

/**
 * ScrollEdgeFade: content dissolves into the panel with a soft blur only at an edge
 * with more to see; the edge you've reached goes crisp again. Scrollbars stay hidden.
 */
export function ScrollFade({ children, className = "", scrollRef, onUserScroll }: { children: ReactNode; className?: string; scrollRef?: Ref<HTMLDivElement>; onUserScroll?: () => void }) {
  const inner = useRef<HTMLDivElement | null>(null);
  const [edges, setEdges] = useState({ top: false, bottom: false });

  useEffect(() => {
    const element = inner.current;
    if (!element) return;
    const measure = () => {
      const top = element.scrollTop > 1;
      const bottom = element.scrollTop + element.clientHeight < element.scrollHeight - 1;
      setEdges((current) => (current.top === top && current.bottom === bottom ? current : { top, bottom }));
    };
    measure();
    const resize = new ResizeObserver(measure);
    resize.observe(element);
    if (element.firstElementChild) resize.observe(element.firstElementChild);
    element.addEventListener("scroll", measure, { passive: true });
    return () => {
      resize.disconnect();
      element.removeEventListener("scroll", measure);
    };
  }, []);

  const stops = [edges.top ? ramp("top") : "#000 0px", edges.bottom ? ramp("bottom").split(", ").reverse().join(", ") : "#000 100%"].join(", ");
  const mask = `linear-gradient(to bottom, ${stops})`;

  return (
    <div className={`relative min-h-0 ${className}`}>
      <div
        ref={(element) => {
          inner.current = element;
          if (typeof scrollRef === "function") scrollRef(element);
          else if (scrollRef) scrollRef.current = element;
        }}
        onWheel={onUserScroll}
        onTouchMove={onUserScroll}
        className="h-full overflow-y-auto overscroll-contain [scrollbar-width:none] [&::-webkit-scrollbar]:hidden"
        style={{ maskImage: mask, WebkitMaskImage: mask }}
      >
        {children}
      </div>
      {(["top", "bottom"] as const).map((edge) => (
        <div
          key={edge}
          aria-hidden
          className="pointer-events-none absolute inset-x-0 backdrop-blur-[5px] transition-opacity duration-200"
          style={{
            [edge]: 0,
            height: fadeLength,
            opacity: edges[edge] ? 1 : 0,
            maskImage: `linear-gradient(to ${edge === "top" ? "bottom" : "top"}, #000 0%, rgba(0,0,0,0.55) 45%, transparent 100%)`,
            WebkitMaskImage: `linear-gradient(to ${edge === "top" ? "bottom" : "top"}, #000 0%, rgba(0,0,0,0.55) 45%, transparent 100%)`,
          }}
        />
      ))}
    </div>
  );
}
