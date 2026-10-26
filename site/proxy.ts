import { NextResponse, type NextRequest } from "next/server";
import { langCookie, type Lang } from "@/lib/lang";

/**
 * The first visit to `/` lands on the visitor's language: a language picked by hand
 * (the cookie) first, then the browser's own list (Accept-Language). Only `/` is ever
 * redirected, and never for crawlers or link previews, so each URL keeps one language
 * for search engines and shared links.
 */
export function proxy(request: NextRequest) {
  if (isBot(request.headers.get("user-agent") ?? "")) return NextResponse.next();
  const chosen = request.cookies.get(langCookie)?.value;
  const wanted: Lang = chosen === "pt" || chosen === "en" ? chosen : preferred(request.headers.get("accept-language") ?? "");
  if (wanted === "en") return NextResponse.redirect(new URL("/en", request.url), 307);
  return NextResponse.next();
}

export const config = { matcher: "/" };

/** Portuguese when it comes before English (or anything else) in the list. */
export function preferred(header: string): Lang {
  const ranked = header
    .split(",")
    .map((part) => {
      const [tag, ...params] = part.trim().toLowerCase().split(";");
      const q = params.find((p) => p.trim().startsWith("q="));
      return { tag: tag ?? "", q: q ? Number(q.trim().slice(2)) || 0 : 1 };
    })
    .filter((entry) => entry.tag && entry.q > 0)
    .sort((a, b) => b.q - a.q);
  if (ranked.length === 0) return "pt";
  return ranked[0]!.tag.startsWith("pt") ? "pt" : "en";
}

function isBot(agent: string): boolean {
  return /bot|crawl|spider|slurp|facebookexternalhit|whatsapp|telegram|discord|slack|linkedin|embedly|preview|vercel/i.test(agent);
}
