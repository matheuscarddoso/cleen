"use client";

import { Brain, Coffee } from "lucide-react";
import { useEffect, useRef, type ReactNode } from "react";
import { notch } from "../../style";
import { isBreak, type TimerPhase } from "./session";

/**
 * The time left as an arc that empties toward the top, like the Clock app's timer
 * (TimerRing). While running it sweeps linearly between the once-a-second updates.
 * `size` is the frame; the stroke sits inside it.
 */
export function TimerRing({
  remaining,
  size,
  lineWidth,
  color = notch.barFill,
  running = false,
  still = false,
  children,
}: {
  remaining: number;
  size: number;
  lineWidth: number;
  color?: string;
  running?: boolean;
  /** Reduced motion: jump, don't sweep. */
  still?: boolean;
  children?: ReactNode;
}) {
  const radius = (size - lineWidth) / 2;
  const circumference = 2 * Math.PI * radius;
  const fraction = Math.max(0, Math.min(1, remaining));
  return (
    <span className="relative flex shrink-0 items-center justify-center" style={{ width: size, height: size }}>
      <svg aria-hidden className="absolute inset-0 -rotate-90" width={size} height={size}>
        <circle cx={size / 2} cy={size / 2} r={radius} fill="none" stroke={notch.track} strokeWidth={lineWidth} />
        <circle
          cx={size / 2}
          cy={size / 2}
          r={radius}
          fill="none"
          stroke={color}
          strokeWidth={lineWidth}
          strokeLinecap="round"
          strokeDasharray={circumference}
          strokeDashoffset={circumference * (1 - fraction)}
          opacity={fraction > 0 ? 1 : 0}
          style={{
            transitionProperty: still ? "none" : "stroke-dashoffset, stroke",
            transitionDuration: running ? "1000ms, 300ms" : "400ms, 300ms",
            transitionTimingFunction: running ? "linear, ease" : "cubic-bezier(0.32, 0.72, 0, 1), ease",
          }}
        />
      </svg>
      <span className="relative flex items-center justify-center">{children}</span>
    </span>
  );
}

/** SF Symbols' "timer": a dial open at the top with its tick, and the hand. */
export function TimerGlyph({ size, color, weight = 1.5 }: { size: number; color: string; weight?: number }) {
  return (
    <svg aria-hidden viewBox="0 0 24 24" width={size} height={size} fill="none" stroke={color} strokeWidth={weight} strokeLinecap="round">
      <path d="M13.4 3.6A9 9 0 1 1 10.6 3.6" />
      <path d="M12 3.4v3.4" />
      <path d="M12 12.6 7.9 8.3" />
      <circle cx="12" cy="12.6" r="0.9" fill={color} stroke="none" />
    </svg>
  );
}

/** The phase's symbol: the dial for a countdown, a head for focus, a cup for a break. */
export function PhaseGlyph({ phase, size, color }: { phase: TimerPhase; size: number; color: string }) {
  if (phase === "countdown") return <TimerGlyph size={size + 2} color={color} weight={1.25} />;
  const Icon = isBreak(phase) ? Coffee : Brain;
  return <Icon size={size} strokeWidth={1.4} color={color} aria-hidden />;
}

/** Breaks read green so a glance tells rest from work. */
export const phaseTint = (phase: TimerPhase) => (isBreak(phase) ? notch.good : notch.barFill);

/**
 * Calls `tick` once a second while `active`. The script's clock runs only while the demo
 * plays; a timer the visitor started runs like the real one, until they pause it.
 */
export function useTicker(active: boolean, tick: () => void) {
  const saved = useRef(tick);
  useEffect(() => {
    saved.current = tick;
  });
  useEffect(() => {
    if (!active) return;
    const timer = window.setInterval(() => saved.current(), 1000);
    return () => window.clearInterval(timer);
  }, [active]);
}

/**
 * The countdown's digits, each one sliding in as it changes (numericText). Static with
 * reduced motion.
 */
export function ClockDigits({ text, still }: { text: string; still: boolean }) {
  return (
    <span className="inline-flex tabular-nums">
      {text.split("").map((char, index) => (
        <span
          key={still ? index : `${text.length - index}-${char}`}
          className={still || char === ":" ? undefined : "motion-safe:animate-[numeric_300ms_ease-out]"}
        >
          {char}
        </span>
      ))}
    </span>
  );
}
