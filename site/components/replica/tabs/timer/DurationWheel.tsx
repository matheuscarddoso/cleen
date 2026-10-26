"use client";

import { useEffect, useRef, useState, type KeyboardEvent, type PointerEvent } from "react";
import { useL } from "@/components/LangProvider";
import { notch } from "../../style";
import { minuteRange } from "./session";

const spacing = 24;
const width = 124;

/**
 * DurationWheel: a compact horizontal wheel of minutes. Drag it, scroll over it or click
 * a neighbouring number; arrow keys step it. The picked number sits in the middle pill,
 * white when it isn't one of the presets.
 */
export function DurationWheel({
  minutes,
  onChange,
  highlighted,
  disabled,
}: {
  minutes: number;
  onChange: (minutes: number) => void;
  highlighted: boolean;
  disabled: boolean;
}) {
  const l = useL();
  const box = useRef<HTMLDivElement>(null);
  const drag = useRef<{ x: number; start: number } | null>(null);
  const [offset, setOffset] = useState(0);
  const [dragging, setDragging] = useState(false);
  const latest = useRef({ minutes, onChange, disabled });
  useEffect(() => {
    latest.current = { minutes, onChange, disabled };
  });

  const clamp = (value: number) => Math.min(minuteRange.max, Math.max(minuteRange.min, value));

  // A wheel over the dial turns it instead of scrolling the page: React's onWheel is
  // passive, so the listener goes on by hand.
  useEffect(() => {
    const element = box.current;
    if (!element) return;
    let accumulated = 0;
    const onWheel = (event: WheelEvent) => {
      if (latest.current.disabled) return;
      event.preventDefault();
      const delta = Math.abs(event.deltaX) > Math.abs(event.deltaY) ? event.deltaX : event.deltaY;
      accumulated += delta;
      const steps = Math.trunc(accumulated / 14);
      if (steps === 0) return;
      accumulated -= steps * 14;
      const next = clamp(latest.current.minutes + steps);
      if (next !== latest.current.minutes) latest.current.onChange(next);
    };
    element.addEventListener("wheel", onWheel, { passive: false });
    return () => element.removeEventListener("wheel", onWheel);
  }, []);

  const onPointerDown = (event: PointerEvent<HTMLDivElement>) => {
    if (disabled) return;
    drag.current = { x: event.clientX, start: minutes };
  };
  const onPointerMove = (event: PointerEvent<HTMLDivElement>) => {
    const current = drag.current;
    if (!current) return;
    // The frame is scaled: measure the finger in the wheel's own points.
    const scale = box.current ? box.current.getBoundingClientRect().width / width : 1;
    const moved = (event.clientX - current.x) / (scale || 1);
    if (!dragging && Math.abs(moved) < 3) return;
    if (!dragging) {
      setDragging(true);
      event.currentTarget.setPointerCapture(event.pointerId);
    }
    // Dragging right brings the smaller numbers in, like turning a dial.
    const next = clamp(current.start - Math.round(moved / spacing));
    const residual = moved - (current.start - next) * spacing;
    const free = spacing / 2;
    setOffset(Math.abs(residual) > free ? Math.sign(residual) * (free + (Math.abs(residual) - free) * 0.2) : residual);
    if (next !== minutes) onChange(next);
  };
  const endDrag = () => {
    drag.current = null;
    setDragging(false);
    setOffset(0);
  };
  const onKeyDown = (event: KeyboardEvent<HTMLDivElement>) => {
    if (disabled) return;
    const step = event.key === "ArrowRight" || event.key === "ArrowUp" ? 1 : event.key === "ArrowLeft" || event.key === "ArrowDown" ? -1 : 0;
    if (step === 0) return;
    event.preventDefault();
    onChange(clamp(minutes + step));
  };

  const values: number[] = [];
  for (let value = Math.max(minuteRange.min, minutes - 4); value <= Math.min(minuteRange.max, minutes + 4); value += 1) values.push(value);

  return (
    <div
      ref={box}
      role="slider"
      tabIndex={disabled ? -1 : 0}
      aria-label={l("Duração", "Duration")}
      aria-valuemin={minuteRange.min}
      aria-valuemax={minuteRange.max}
      aria-valuenow={minutes}
      aria-valuetext={l(`${minutes} minutos`, `${minutes} minutes`)}
      aria-disabled={disabled}
      title={l("Arraste ou role para escolher os minutos", "Drag or scroll to choose the minutes")}
      onPointerDown={onPointerDown}
      onPointerMove={onPointerMove}
      onPointerUp={endDrag}
      onPointerCancel={endDrag}
      onKeyDown={onKeyDown}
      className="relative h-[26px] shrink-0 touch-none select-none overflow-hidden rounded-full bg-white/10 transition-[background-color,opacity] duration-150 hover:bg-white/[0.16]"
      style={{ width, opacity: disabled ? 0.4 : 1, cursor: disabled ? "default" : dragging ? "grabbing" : "grab", pointerEvents: disabled ? "none" : undefined }}
    >
      <div
        className="absolute inset-0"
        style={{ maskImage: "linear-gradient(to right, transparent 0%, #000 22%, #000 78%, transparent 100%)" }}
      >
        <span
          className="absolute left-1/2 top-1/2 h-5 w-[30px] -translate-x-1/2 -translate-y-1/2 rounded-full transition-colors duration-200"
          style={{ background: highlighted ? "#fff" : notch.selection }}
        />
        {values.map((value) => {
          const distance = value - minutes + offset / spacing;
          const selected = value === minutes;
          return (
            <span
              key={value}
              onClick={() => !disabled && onChange(value)}
              className="absolute left-1/2 top-0 flex h-[26px] items-center justify-center text-[11.5px] font-medium tabular-nums"
              style={{
                width: spacing,
                marginLeft: -spacing / 2,
                color: selected && highlighted ? "#000" : notch.primary,
                opacity: selected ? 1 : Math.max(0, 0.75 - Math.abs(distance) * 0.17),
                transform: `translateX(${distance * spacing}px) scale(${1 - Math.min(Math.abs(distance), 3) * 0.06})`,
                transitionProperty: dragging ? "color" : "transform, opacity, color",
                transitionDuration: "220ms",
                transitionTimingFunction: "cubic-bezier(0.32, 0.72, 0, 1)",
              }}
            >
              {value}
            </span>
          );
        })}
      </div>
    </div>
  );
}
