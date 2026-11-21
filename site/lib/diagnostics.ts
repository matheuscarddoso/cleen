import { createHash, timingSafeEqual } from "node:crypto";
import { mkdir, readdir, readFile, rename, writeFile } from "node:fs/promises";
import path from "node:path";

/**
 * Error reports from the app (Sources/Cleen/Diagnostics): crashes of Cleen and its
 * helpers, hangs, CPU and disk-write excesses, and failures the app reports itself.
 *
 * Stored on disk under `DIAGNOSTICS_DIR`, one folder per signature (the same problem has
 * the same signature on every Mac):
 *
 *   <signature>/group.json            what the problem is, how often, on which versions
 *   <signature>/<time>-<id>.json      the first SAMPLES_PER_GROUP reports, whole
 *
 * Nothing about the sender is kept: no IP, no headers. The app scrubs every report
 * before sending; this side only checks the shape and the sizes.
 */

/** A crash report with every thread is ~20–100 KB; MetricKit's are smaller. */
export const MAX_BODY_BYTES = 1_000_000;
/** Reports kept whole for each problem; the rest are only counted. */
export const SAMPLES_PER_GROUP = 25;
/** Problems tracked at most: past this, new ones are counted nowhere (and not retried). */
export const MAX_GROUPS = 5_000;

export const KINDS = ["crash", "hang", "cpu-exception", "disk-writes", "error"] as const;
export type Kind = (typeof KINDS)[number];

/** The app's `DiagnosticReport` (Sources/CleenKit/Diagnostics/DiagnosticReport.swift). */
export interface Report {
  schema: 1;
  id: string;
  kind: Kind;
  signature: string;
  summary: string;
  process: string;
  occurredAt: string;
  app: { version: string; build: string };
  system: { os: string; model: string };
  install: string;
  breadcrumbs: string[];
  report: string;
}

export interface Group {
  signature: string;
  kind: Kind;
  process: string;
  summary: string;
  firstSeen: string;
  lastSeen: string;
  /** Every report received for it, kept whole or not. */
  count: number;
  /** Reports per app version ("1.2.4 (174)"). */
  versions: Record<string, number>;
  /** Distinct installs that hit it: each install's value is unique to this signature. */
  installs: number;
  samples: number;
}

/** What `group.json` holds besides the public summary, to count without double-counting. */
interface StoredGroup extends Group {
  installIDs: string[];
  recentIDs: string[];
}

const HEX16 = /^[0-9a-f]{16}$/;
const UUID = /^[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}$/i;
const SAMPLE_FILE = /^\d{10,16}-[0-9A-F-]{36}\.json$/i;

// MARK: Validation

function text(value: unknown, max: number): string | null {
  return typeof value === "string" && value.length > 0 && value.length <= max ? value : null;
}

/**
 * The report if it has exactly the app's shape and sizes, rebuilt from those fields
 * only (anything else in the body is dropped); null otherwise.
 */
export function parseReport(value: unknown, now: Date = new Date()): Report | null {
  if (typeof value !== "object" || value === null) return null;
  const input = value as Record<string, unknown>;
  const app = input.app as Record<string, unknown> | undefined;
  const system = input.system as Record<string, unknown> | undefined;
  if (input.schema !== 1 || typeof app !== "object" || app === null || typeof system !== "object" || system === null) return null;

  const id = text(input.id, 36);
  const kind = KINDS.find((k) => k === input.kind);
  const signature = text(input.signature, 16);
  const install = text(input.install, 16);
  const summary = text(input.summary, 400);
  const processName = text(input.process, 120);
  const occurredAt = text(input.occurredAt, 40);
  const version = text(app.version, 32);
  const build = text(app.build, 32);
  const os = text(system.os, 80);
  const model = text(system.model, 80);
  const report = text(input.report, MAX_BODY_BYTES);
  if (!id || !UUID.test(id) || !kind || !signature || !HEX16.test(signature) || !install || !HEX16.test(install)) return null;
  if (!summary || !processName || !occurredAt || !version || !build || !os || !model || !report) return null;

  // Not from the future (a skewed clock is allowed a day), not older than the app keeps them.
  const time = Date.parse(occurredAt);
  if (Number.isNaN(time) || time > now.getTime() + 86_400_000 || time < now.getTime() - 30 * 86_400_000) return null;

  const crumbs = input.breadcrumbs;
  if (!Array.isArray(crumbs) || crumbs.length > 200 || !crumbs.every((line) => typeof line === "string" && line.length <= 600)) return null;

  return {
    schema: 1,
    id,
    kind,
    signature,
    summary,
    process: processName,
    occurredAt: new Date(time).toISOString(),
    app: { version, build },
    system: { os, model },
    install,
    breadcrumbs: crumbs as string[],
    report,
  };
}

// MARK: Storage

export interface Added {
  /** Kept whole (false: counted only, or a resend already counted). */
  stored: boolean;
  /** A report this server already had (the app resends when an answer gets lost). */
  duplicate: boolean;
}

export class DiagnosticsStore {
  readonly root: string;
  /** One update of a group at a time: `group.json` is read, changed and written back. */
  private readonly locks = new Map<string, Promise<unknown>>();

  constructor(root: string) {
    this.root = root;
  }

  add(report: Report): Promise<Added> {
    return this.locked(report.signature, () => this.write(report));
  }

  /** Every problem, the most recent first. */
  async groups(): Promise<Group[]> {
    const names = await readdir(this.root).catch(() => [] as string[]);
    const groups = await Promise.all(names.filter((name) => HEX16.test(name)).map((name) => this.readGroup(name)));
    return groups.filter((group): group is StoredGroup => group !== null).map(publicGroup).sort((a, b) => b.lastSeen.localeCompare(a.lastSeen));
  }

  /** One problem and the reports kept for it, newest first; null when there's no such problem. */
  async group(signature: string): Promise<{ group: Group; samples: string[] } | null> {
    if (!HEX16.test(signature)) return null;
    const group = await this.readGroup(signature);
    if (!group) return null;
    const files = await readdir(path.join(this.root, signature)).catch(() => [] as string[]);
    const samples = files.filter((name) => SAMPLE_FILE.test(name)).sort().reverse();
    return { group: publicGroup(group), samples };
  }

  /** One kept report, whole. */
  async sample(signature: string, file: string): Promise<Report | null> {
    if (!HEX16.test(signature) || !SAMPLE_FILE.test(file)) return null;
    const data = await readFile(path.join(this.root, signature, file), "utf8").catch(() => null);
    return data ? (JSON.parse(data) as Report) : null;
  }

  private async write(report: Report): Promise<Added> {
    const folder = path.join(this.root, report.signature);
    let group = await this.readGroup(report.signature);
    if (!group) {
      const known = await readdir(this.root).catch(() => [] as string[]);
      if (known.filter((name) => HEX16.test(name)).length >= MAX_GROUPS) return { stored: false, duplicate: false };
      await mkdir(folder, { recursive: true });
      group = {
        signature: report.signature,
        kind: report.kind,
        process: report.process,
        summary: report.summary,
        firstSeen: report.occurredAt,
        lastSeen: report.occurredAt,
        count: 0,
        versions: {},
        installs: 0,
        samples: 0,
        installIDs: [],
        recentIDs: [],
      };
    }
    if (group.recentIDs.includes(report.id)) return { stored: false, duplicate: true };

    group.count += 1;
    const version = `${report.app.version} (${report.app.build})`;
    group.versions[version] = (group.versions[version] ?? 0) + 1;
    if (report.occurredAt < group.firstSeen) group.firstSeen = report.occurredAt;
    if (report.occurredAt > group.lastSeen) {
      group.lastSeen = report.occurredAt;
      // The latest words win: a newer build may name the problem better.
      group.summary = report.summary;
    }
    if (!group.installIDs.includes(report.install) && group.installIDs.length < 1_000) group.installIDs.push(report.install);
    group.installs = group.installIDs.length;
    group.recentIDs = [...group.recentIDs, report.id].slice(-200);

    let stored = false;
    if (group.samples < SAMPLES_PER_GROUP) {
      await atomicWrite(path.join(folder, `${Date.parse(report.occurredAt)}-${report.id}.json`), JSON.stringify(report, null, 2));
      group.samples += 1;
      stored = true;
    }
    await atomicWrite(path.join(folder, "group.json"), JSON.stringify(group, null, 2));
    return { stored, duplicate: false };
  }

  private async readGroup(signature: string): Promise<StoredGroup | null> {
    const data = await readFile(path.join(this.root, signature, "group.json"), "utf8").catch(() => null);
    if (!data) return null;
    try {
      return JSON.parse(data) as StoredGroup;
    } catch {
      return null;
    }
  }

  private locked<T>(key: string, work: () => Promise<T>): Promise<T> {
    const previous = this.locks.get(key) ?? Promise.resolve();
    const next = previous.catch(() => undefined).then(work);
    this.locks.set(key, next);
    void next.finally(() => {
      if (this.locks.get(key) === next) this.locks.delete(key);
    }).catch(() => undefined);
    return next;
  }
}

function publicGroup(group: StoredGroup): Group {
  const { installIDs: _installs, recentIDs: _recent, ...rest } = group;
  return rest;
}

/** Written beside and renamed over: a reader never sees half a file. */
async function atomicWrite(file: string, data: string): Promise<void> {
  const temporary = `${file}.${process.pid}.${Date.now()}.tmp`;
  await writeFile(temporary, data, "utf8");
  await rename(temporary, file);
}

// MARK: Who's asking

/** Requests per client in a window, kept in memory only (one server instance). */
export class RateLimiter {
  private readonly hits = new Map<string, number[]>();
  readonly limit: number;
  readonly windowMs: number;

  constructor(limit: number, windowMs: number) {
    this.limit = limit;
    this.windowMs = windowMs;
  }

  allow(key: string, now: number = Date.now()): boolean {
    const recent = (this.hits.get(key) ?? []).filter((time) => now - time < this.windowMs);
    if (recent.length >= this.limit) {
      this.hits.set(key, recent);
      return false;
    }
    recent.push(now);
    this.hits.set(key, recent);
    // Forget clients gone quiet, so the map can't grow without bound.
    if (this.hits.size > 10_000) {
      for (const [client, times] of this.hits) {
        if (times.every((time) => now - time >= this.windowMs)) this.hits.delete(client);
      }
    }
    return true;
  }
}

/** The bearer token, compared in constant time (hashed first, so lengths can't tell either). */
export function authorized(header: string | null, token: string): boolean {
  if (!header?.startsWith("Bearer ") || token.length < 32) return false;
  const given = createHash("sha256").update(header.slice("Bearer ".length)).digest();
  const expected = createHash("sha256").update(token).digest();
  return timingSafeEqual(given, expected);
}
