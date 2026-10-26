/**
 * The replica's Mac: a scripted day in the life of its vitals, one sample per tick. A
 * quiet stretch, a big download (the network line climbs, the disk loses a little), a
 * build that pins the CPU and presses memory (bars go orange, then red), and the cool
 * down. Noise comes from a seeded generator so every run reads the same.
 */
import type { Lang } from "@/lib/lang";
import { random } from "../stocks/market";

const gib = 1024 ** 3;

export const memoryTotal = 8 * gib;
export const diskTotal = 245.11e9;
/** Swift Charts' x domain in Sparkline: room for a minute of samples. */
export const historyCapacity = 60;

export type Vitals = {
  tick: number;
  /** 0...1 */
  cpu: number;
  memoryUsed: number;
  diskFree: number;
  /** Bytes per second. */
  download: number;
  upload: number;
  downloadHistory: number[];
  battery: { level: number; charging: boolean; health: number };
};

/** What the tab shows before anything moves, and the reduced-motion still: the real screenshot's reading. */
export const firstVitals: Vitals = {
  tick: 0,
  cpu: 0.6,
  memoryUsed: 6.38 * gib,
  diskFree: 51.78e9,
  download: 185_000,
  upload: 33_000,
  downloadHistory: [21_000, 18_000, 24_000, 19_000, 22_000, 20_000, 26_000, 31_000, 64_000, 185_000],
  battery: { level: 1, charging: true, health: 0.83 },
};

/** Ticks in one loop of the script. */
export const loopLength = 30;

type Target = { cpu: number; memory: number; download: number; upload: number; diskDrain: number };

/** Where each phase of the loop pulls the readings. */
function target(tick: number): Target {
  const at = tick % loopLength;
  if (at >= 6 && at < 13) return { cpu: 0.34, memory: 0.74, download: 18e6 + (at - 6) * 1.4e6, upload: 60_000, diskDrain: 0.11e9 };
  if (at >= 13 && at < 21) return { cpu: at < 15 ? 0.82 : 0.95, memory: at < 16 ? 0.86 : 0.93, download: 140_000, upload: 1.6e6, diskDrain: 0 };
  if (at >= 21 && at < 25) return { cpu: 0.42, memory: 0.8, download: 90_000, upload: 40_000, diskDrain: -0.19e9 };
  return { cpu: 0.27, memory: 0.76, download: 70_000, upload: 28_000, diskDrain: -0.02e9 };
}

/** The next sample: each reading eases toward its phase with a little noise on top. */
export function step(current: Vitals, seed: number): Vitals {
  const next = random(seed + current.tick * 7919);
  const aim = target(current.tick + 1);
  const noise = (scale: number) => (next() - 0.5) * 2 * scale;
  const ease = (from: number, to: number, rate: number) => from + (to - from) * rate;

  const cpu = clamp(ease(current.cpu, aim.cpu, 0.55) + noise(0.06), 0.06, 0.99);
  const memoryFraction = clamp(ease(current.memoryUsed / memoryTotal, aim.memory, 0.35) + noise(0.006), 0.55, 0.97);
  const download = Math.max(4_000, ease(current.download, aim.download, 0.6) * (1 + noise(0.35)));
  const upload = Math.max(2_000, ease(current.upload, aim.upload, 0.6) * (1 + noise(0.3)));
  const diskFree = clamp(current.diskFree - aim.diskDrain * (0.8 + next() * 0.4), 50.6e9, 51.9e9);
  const downloadHistory = [...current.downloadHistory, download].slice(-historyCapacity);

  return { ...current, tick: current.tick + 1, cpu, memoryUsed: memoryFraction * memoryTotal, diskFree, download, upload, downloadHistory };
}

/** Memory pressure as the app reads it: the colour of the row, when it's not "normal". */
export function pressure(used: number): "normal" | "warning" | "critical" {
  const fraction = used / memoryTotal;
  if (fraction >= 0.91) return "critical";
  if (fraction >= 0.78) return "warning";
  return "normal";
}

function clamp(value: number, low: number, high: number): number {
  return Math.min(Math.max(value, low), high);
}

// MARK: Formatting, like Foundation's byte counts in each locale

/** `6,38` in Portuguese, `6.38` in English. */
function decimal(value: number, digits: number, lang: Lang): string {
  const text = value.toFixed(digits);
  return lang === "pt" ? text.replace(".", ",") : text;
}

/** `60%` */
export function percent(fraction: number): string {
  return `${Math.round(fraction * 100)}%`;
}

/** `6,38 GB` (`6.38 GB` in English) in binary units (the memory style). */
export function memoryBytes(bytes: number, lang: Lang = "pt"): string {
  return `${decimal(bytes / gib, 2, lang)} GB`;
}

/** `51,78 GB`, `185 kB`, `12,4 MB`: decimal units, the file style. English reads `51.78 GB`, `185 KB`. */
export function bytes(value: number, lang: Lang = "pt"): string {
  if (value >= 1e9) return `${decimal(value / 1e9, 2, lang)} GB`;
  if (value >= 999_500) return `${decimal(value / 1e6, 1, lang)} MB`;
  if (value >= 1e3) return `${Math.round(value / 1e3)} ${lang === "pt" ? "kB" : "KB"}`;
  return `${Math.round(value)} bytes`;
}

export function rate(perSecond: number, lang: Lang = "pt"): string {
  return `${bytes(perSecond, lang)}/s`;
}
