/** What the overview knows about the Mac: the disk, and what each scan found. */
export type Findings = {
  free: number;
  total: number;
  /** Lixo: everything found, and the safe defaults one click cleans. */
  junk: number;
  junkSafe: number;
  /** Projetos parados: the same split. */
  projects: number;
  projectsSafe: number;
  /** Restos de apps: only listed, never in the one-click clean. */
  orphans: number;
};

/** Where AppModel's smart scan and clean are. `found` counts scans back (Lixo, Restos, Projetos). */
export type Disk = {
  phase: "idle" | "scanning" | "ready" | "cleaning";
  scanned: boolean;
  found: number;
  armed: boolean;
  pressed: boolean;
  /** Bytes the last cleanup freed (NotchReportLine), until the next scan. */
  report: number | null;
  data: Findings;
};

/** A made-up but typical Mac: 245 GB disk, 79% used, 1,28 GB of safe junk. */
export const findings: Findings = {
  free: 51.78e9,
  total: 245.11e9,
  junk: 2.26e9,
  junkSafe: 868e6,
  projects: 669e6,
  projectsSafe: 412e6,
  orphans: 487e3,
};

/** The same Mac after "Limpar": the safe parts gone, the space back. */
export function cleaned(data: Findings): Findings {
  return {
    ...data,
    free: data.free + data.junkSafe + data.projectsSafe,
    junk: data.junk - data.junkSafe,
    junkSafe: 0,
    projects: data.projects - data.projectsSafe,
    projectsSafe: 0,
  };
}

/** A scan some time after a cleanup: caches have grown back a little. */
export function rescanned(data: Findings): Findings {
  if (data.junkSafe > 0) return data;
  return { ...data, junk: data.junk + 46e6, junkSafe: 46e6 };
}

/** The one-click clean, 0.0–1.28 GB: Lixo's and Projetos parados' safe defaults. */
export function cleanSize(data: Findings) {
  return data.junkSafe + data.projectsSafe;
}

const formats = [0, 1, 2].map((digits) => new Intl.NumberFormat("pt-BR", { maximumFractionDigits: digits }));

/** `.byteCount(style: .file)` in Portuguese: decimal units, 0 digits for kB, 1 for MB, 2 above. */
export function bytes(value: number): string {
  const units = ["kB", "MB", "GB", "TB"] as const;
  if (value < 1000) return `${Math.round(value)} bytes`;
  let amount = value / 1000;
  let unit = 0;
  while (amount >= 1000 && unit < units.length - 1) {
    amount /= 1000;
    unit += 1;
  }
  return `${formats[Math.min(unit, 2)]!.format(amount)} ${units[unit]}`;
}

const percent = new Intl.NumberFormat("pt-BR", { style: "percent", maximumFractionDigits: 0 });

export function usedFraction(data: Findings) {
  return (data.total - data.free) / data.total;
}

export function formatPercent(fraction: number) {
  return percent.format(fraction);
}
