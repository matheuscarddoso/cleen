import { NextResponse, type NextRequest } from "next/server";
import { authorized, DiagnosticsStore, MAX_BODY_BYTES, parseReport, RateLimiter } from "@/lib/diagnostics";

/**
 * POST: an error report from the app (see lib/diagnostics.ts). Open to every install,
 * so it's bounded: size, shape, and how often one client may send.
 *
 * GET: reading them back, with `Authorization: Bearer $DIAGNOSTICS_TOKEN`
 * (scripts/diagnostics.sh in the repository root does it):
 *   /api/diagnostics                          every problem, most recent first
 *   /api/diagnostics?signature=<s>            one problem and its kept reports
 *   /api/diagnostics?signature=<s>&report=<f> one report, whole
 *
 * Needs DIAGNOSTICS_DIR (a persistent volume) and, to read, DIAGNOSTICS_TOKEN. Without
 * the folder it answers 503, and the app keeps its reports queued until it's there.
 */
export const runtime = "nodejs";
export const dynamic = "force-dynamic";

/** A crash loop on one Mac sends a few a minute; this is far past any real one. */
const perClient = new RateLimiter(60, 10 * 60_000);
const everyone = new RateLimiter(5_000, 60 * 60_000);

let store: DiagnosticsStore | null = null;

function configuredStore(): DiagnosticsStore | null {
  const folder = process.env.DIAGNOSTICS_DIR;
  if (!folder) return null;
  if (store?.root !== folder) store = new DiagnosticsStore(folder);
  return store;
}

function json(body: unknown, status: number, headers: Record<string, string> = {}): NextResponse {
  return NextResponse.json(body, { status, headers: { "Cache-Control": "no-store", ...headers } });
}

/** The first address the proxy saw; used for the rate limit only, never stored. */
function client(request: NextRequest): string {
  return request.headers.get("x-forwarded-for")?.split(",")[0]?.trim() || request.headers.get("x-real-ip") || "unknown";
}

/** The body as text, or null once it passes `limit` bytes (read no further). */
async function readCapped(request: NextRequest, limit: number): Promise<string | null> {
  if (!request.body) return "";
  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let size = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    size += value.byteLength;
    if (size > limit) {
      await reader.cancel();
      return null;
    }
    chunks.push(value);
  }
  return Buffer.concat(chunks).toString("utf8");
}

export async function POST(request: NextRequest): Promise<NextResponse> {
  const reports = configuredStore();
  if (!reports) return json({ error: "not configured" }, 503, { "Retry-After": "3600" });
  if (!perClient.allow(client(request)) || !everyone.allow("all")) return json({ error: "too many reports" }, 429, { "Retry-After": "600" });
  if (Number(request.headers.get("content-length") ?? 0) > MAX_BODY_BYTES) return json({ error: "too large" }, 413);

  const text = await readCapped(request, MAX_BODY_BYTES);
  if (text === null) return json({ error: "too large" }, 413);
  let body: unknown;
  try {
    body = JSON.parse(text);
  } catch {
    return json({ error: "not json" }, 400);
  }
  const report = parseReport(body);
  if (!report) return json({ error: "not a report" }, 400);

  try {
    const added = await reports.add(report);
    return json({ ok: true, stored: added.stored }, 202);
  } catch (error) {
    console.error("diagnostics: couldn't store a report", error);
    return json({ error: "storage failed" }, 500);
  }
}

export async function GET(request: NextRequest): Promise<NextResponse> {
  const token = process.env.DIAGNOSTICS_TOKEN;
  const reports = configuredStore();
  if (!token || !reports) return json({ error: "not configured" }, 503);
  if (!authorized(request.headers.get("authorization"), token)) return json({ error: "unauthorized" }, 401, { "WWW-Authenticate": "Bearer" });

  const signature = request.nextUrl.searchParams.get("signature");
  const file = request.nextUrl.searchParams.get("report");
  if (!signature) return json({ groups: await reports.groups() }, 200);
  if (!file) {
    const found = await reports.group(signature);
    return found ? json(found, 200) : json({ error: "no such problem" }, 404);
  }
  const report = await reports.sample(signature, file);
  return report ? json(report, 200) : json({ error: "no such report" }, 404);
}
