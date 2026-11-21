import assert from "node:assert/strict";
import { mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { describe, it } from "node:test";
import { authorized, DiagnosticsStore, parseReport, RateLimiter, SAMPLES_PER_GROUP, type Report } from "./diagnostics.ts";

const now = new Date("2026-11-21T12:00:00Z");

function report(overrides: Partial<Report> = {}): Record<string, unknown> {
  return {
    schema: 1,
    id: crypto.randomUUID().toUpperCase(),
    kind: "crash",
    signature: "a2a105db8514c4c1",
    summary: "perl · EXC_CRASH (SIGABRT) · libCleenNowPlaying.dylib Write",
    process: "perl",
    occurredAt: "2026-11-20T13:48:34Z",
    app: { version: "1.2.4", build: "174" },
    system: { os: "macOS 26.5.1 (25F80)", model: "Mac15,12" },
    install: "0123456789abcdef",
    breadcrumbs: ["2026-11-20T13:48:30.000Z W [now-playing] helper exited; restarting in 2 seconds"],
    report: "{}",
    ...overrides,
  };
}

async function withStore(work: (store: DiagnosticsStore) => Promise<void>): Promise<void> {
  const folder = await mkdtemp(path.join(tmpdir(), "cleen-diagnostics-"));
  try {
    await work(new DiagnosticsStore(folder));
  } finally {
    await rm(folder, { recursive: true, force: true });
  }
}

describe("parseReport", () => {
  it("takes the app's report as it is", () => {
    const parsed = parseReport(report(), now);
    assert.ok(parsed);
    assert.equal(parsed.signature, "a2a105db8514c4c1");
    assert.equal(parsed.occurredAt, "2026-11-20T13:48:34.000Z");
  });

  it("keeps only the fields it knows", () => {
    const parsed = parseReport({ ...report(), ip: "203.0.113.9", extra: { a: 1 } }, now) as unknown as Record<string, unknown>;
    assert.equal(parsed.ip, undefined);
    assert.equal(parsed.extra, undefined);
  });

  it("refuses anything else", () => {
    assert.equal(parseReport(null, now), null);
    assert.equal(parseReport(report({ schema: 2 as 1 }), now), null);
    assert.equal(parseReport(report({ kind: "panic" as "crash" }), now), null);
    assert.equal(parseReport(report({ signature: "../../etc/passwd" }), now), null);
    assert.equal(parseReport(report({ install: "not-hex-at-all!!" }), now), null);
    assert.equal(parseReport(report({ id: "1" }), now), null);
    assert.equal(parseReport(report({ summary: "" }), now), null);
    assert.equal(parseReport(report({ breadcrumbs: Array(201).fill("x") }), now), null);
    assert.equal(parseReport(report({ breadcrumbs: ["x".repeat(601)] }), now), null);
  });

  it("refuses times from the future or too long ago", () => {
    assert.equal(parseReport(report({ occurredAt: "2026-11-23T12:00:00Z" }), now), null);
    assert.equal(parseReport(report({ occurredAt: "2026-09-01T12:00:00Z" }), now), null);
    assert.equal(parseReport(report({ occurredAt: "yesterday" }), now), null);
  });
});

describe("DiagnosticsStore", () => {
  it("groups the same problem and counts what it saw", async () => {
    await withStore(async (store) => {
      await store.add(parseReport(report({ install: "1111111111111111" }), now)!);
      await store.add(parseReport(report({ install: "2222222222222222", app: { version: "1.2.5", build: "180" } }), now)!);
      await store.add(parseReport(report({ install: "1111111111111111", occurredAt: "2026-11-21T09:00:00Z", summary: "newer words" }), now)!);
      await store.add(parseReport(report({ signature: "ffffffffffffffff", kind: "hang", occurredAt: "2026-11-19T10:00:00Z" }), now)!);

      const groups = await store.groups();
      assert.deepEqual(groups.map((group) => group.signature), ["a2a105db8514c4c1", "ffffffffffffffff"]);
      const crash = groups[0]!;
      assert.equal(crash.count, 3);
      assert.equal(crash.installs, 2);
      assert.deepEqual(crash.versions, { "1.2.4 (174)": 2, "1.2.5 (180)": 1 });
      assert.equal(crash.firstSeen, "2026-11-20T13:48:34.000Z");
      assert.equal(crash.lastSeen, "2026-11-21T09:00:00.000Z");
      assert.equal(crash.summary, "newer words");
      // What tells installs apart never leaves the server.
      assert.equal((crash as unknown as Record<string, unknown>).installIDs, undefined);
    });
  });

  it("keeps a few reports whole and only counts the rest", async () => {
    await withStore(async (store) => {
      for (let index = 0; index < SAMPLES_PER_GROUP + 5; index += 1) await store.add(parseReport(report(), now)!);
      const found = await store.group("a2a105db8514c4c1");
      assert.ok(found);
      assert.equal(found.group.count, SAMPLES_PER_GROUP + 5);
      assert.equal(found.samples.length, SAMPLES_PER_GROUP);
      const sample = await store.sample("a2a105db8514c4c1", found.samples[0]!);
      assert.equal(sample?.process, "perl");
    });
  });

  it("counts a resent report once", async () => {
    await withStore(async (store) => {
      const once = parseReport(report(), now)!;
      assert.deepEqual(await store.add(once), { stored: true, duplicate: false });
      assert.deepEqual(await store.add(once), { stored: false, duplicate: true });
      assert.equal((await store.groups())[0]?.count, 1);
    });
  });

  it("takes reports arriving at once without losing any", async () => {
    await withStore(async (store) => {
      await Promise.all(Array.from({ length: 20 }, () => store.add(parseReport(report(), now)!)));
      assert.equal((await store.groups())[0]?.count, 20);
    });
  });

  it("never reads outside its folder", async () => {
    await withStore(async (store) => {
      assert.equal(await store.group("../.."), null);
      assert.equal(await store.sample("a2a105db8514c4c1", "../group.json"), null);
      assert.equal(await store.sample("a2a105db8514c4c1", "/etc/passwd"), null);
    });
  });
});

describe("RateLimiter", () => {
  it("lets a client send up to the limit in the window, then again after it", () => {
    const limiter = new RateLimiter(2, 1_000);
    assert.equal(limiter.allow("a", 0), true);
    assert.equal(limiter.allow("a", 10), true);
    assert.equal(limiter.allow("a", 20), false);
    assert.equal(limiter.allow("b", 20), true);
    assert.equal(limiter.allow("a", 1_011), true);
  });
});

describe("authorized", () => {
  const token = "t".repeat(40);

  it("takes the token and nothing else", () => {
    assert.equal(authorized(`Bearer ${token}`, token), true);
    assert.equal(authorized(`Bearer ${token}x`, token), false);
    assert.equal(authorized(token, token), false);
    assert.equal(authorized(null, token), false);
  });

  it("refuses a token too short to be one", () => {
    assert.equal(authorized("Bearer short", "short"), false);
  });
});
