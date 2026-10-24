"use client";

import type { LucideIcon } from "lucide-react";
import { useId, type ReactNode } from "react";
import { level, notch } from "../../style";
import { NumericText } from "../stocks/NumericText";
import { historyCapacity } from "./vitals";

/**
 * One line of the group (NotchMeterRow): glyph, label at a fixed width so the bars line
 * up, the wide middle, and the value on the right with an optional second line.
 */
export function MeterRow({
  icon: Icon,
  label,
  value,
  valueColor = notch.primary,
  iconSize = 12.5,
  detail,
  animated,
  children,
}: {
  icon: LucideIcon;
  /** SF draws some glyphs wider than others (the battery); Lucide's need a nudge to match. */
  iconSize?: number;
  label: string;
  value: string;
  valueColor?: string;
  detail?: string;
  animated: boolean;
  children: ReactNode;
}) {
  return (
    <li className="flex h-7 items-center gap-2.5 px-3">
      <span className="flex w-4 shrink-0 justify-center" style={{ color: notch.secondary }}>
        <Icon size={iconSize} strokeWidth={2} aria-hidden />
      </span>
      <span className="w-[92px] shrink-0 truncate text-[12px] font-medium text-white/85">{label}</span>
      <span className="flex min-w-0 flex-1 items-center">{children}</span>
      <span className="flex min-w-[70px] shrink-0 flex-col items-end">
        <span className="whitespace-nowrap text-[11.5px] font-semibold leading-[14px] transition-[color] duration-300" style={{ color: valueColor }}>
          <NumericText value={value} animated={animated} />
        </span>
        {detail && (
          <span className="whitespace-nowrap text-[9.5px] leading-[11px]" style={{ color: notch.tertiary }}>
            {detail}
          </span>
        )}
      </span>
    </li>
  );
}

/** A thin quota bar (UsageBar, 3.5 tall): white with room, orange then red as it fills. */
export function UsageBar({ fraction, tint }: { fraction: number; tint?: string }) {
  const clamped = Math.min(Math.max(fraction, 0), 1);
  return (
    <span aria-hidden className="relative block h-[3.5px] w-full overflow-hidden rounded-full" style={{ background: notch.track }}>
      <span
        className="absolute inset-y-0 left-0 rounded-full transition-[width,background-color] duration-300"
        style={{ width: `${clamped * 100}%`, background: tint ?? level(clamped), transitionTimingFunction: "cubic-bezier(0.32, 0.72, 0, 1)" }}
      />
    </span>
  );
}

/**
 * The tiny area chart of recent samples (Sparkline): a monotone line over a fading
 * fill, oldest on the left, room for a minute of samples, scaled to the peak.
 */
export function Sparkline({ values, tint = notch.barFill, height = 14 }: { values: readonly number[]; tint?: string; height?: number }) {
  const gradient = `area${useId().replace(/[^a-zA-Z0-9]/g, "")}`;
  const width = 100;
  const top = Math.max(Math.max(...values, 1) * 1.15, 1);
  const inset = 0.75;
  const points = values.map((value, index): [number, number] => [
    (index / (historyCapacity - 1)) * width,
    inset + (1 - value / top) * (height - inset * 2),
  ]);
  const line = monotone(points);
  const last = points[points.length - 1];
  const first = points[0];
  return (
    <svg aria-hidden viewBox={`0 0 ${width} ${height}`} preserveAspectRatio="none" className="block w-full overflow-visible" style={{ height }}>
      <defs>
        <linearGradient id={gradient} x1="0" y1="0" x2="0" y2="1">
          <stop offset="0" stopColor={tint} stopOpacity={0.28} />
          <stop offset="1" stopColor={tint} stopOpacity={0} />
        </linearGradient>
      </defs>
      {line && first && last && (
        <>
          <path d={`${line} L${round(last[0])} ${height} L${round(first[0])} ${height} Z`} fill={`url(#${gradient})`} />
          <path d={line} fill="none" stroke={tint} strokeWidth={1.25} strokeLinejoin="round" strokeLinecap="round" vectorEffect="non-scaling-stroke" />
        </>
      )}
    </svg>
  );
}

/** Swift Charts' `.monotone`: a cubic through every sample that never overshoots (Fritsch–Carlson). */
function monotone(points: readonly [number, number][]): string {
  const count = points.length;
  if (count < 2) return "";
  const slopes: number[] = [];
  for (let index = 0; index < count - 1; index += 1) {
    const [x0, y0] = points[index]!;
    const [x1, y1] = points[index + 1]!;
    slopes.push((y1 - y0) / (x1 - x0));
  }
  const tangents = points.map((_, index) => {
    if (index === 0) return slopes[0]!;
    if (index === count - 1) return slopes[count - 2]!;
    const before = slopes[index - 1]!;
    const after = slopes[index]!;
    if (before * after <= 0) return 0;
    return (Math.sign(before) + Math.sign(after)) * Math.min(Math.abs(before), Math.abs(after), 0.5 * Math.abs((before + after) / 2));
  });
  let path = `M${round(points[0]![0])} ${round(points[0]![1])}`;
  for (let index = 0; index < count - 1; index += 1) {
    const [x0, y0] = points[index]!;
    const [x1, y1] = points[index + 1]!;
    const third = (x1 - x0) / 3;
    path += ` C${round(x0 + third)} ${round(y0 + tangents[index]! * third)} ${round(x1 - third)} ${round(y1 - tangents[index + 1]! * third)} ${round(x1)} ${round(y1)}`;
  }
  return path;
}

function round(value: number): number {
  return Math.round(value * 100) / 100;
}
