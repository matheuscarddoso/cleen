/** The site's languages: Portuguese at `/`, English at `/en`. */
export type Lang = "pt" | "en";

export const langs: readonly Lang[] = ["pt", "en"];

/** Where each language's page lives. */
export const home: Record<Lang, string> = { pt: "/", en: "/en" };

/** BCP 47 tags, for `<html lang>`, `Intl` and `hreflang`. */
export const locale: Record<Lang, string> = { pt: "pt-BR", en: "en-US" };

/** The cookie that remembers a language picked by hand; it wins over the browser's. */
export const langCookie = "lang";

/**
 * Picks the text (or any value) for a language: `l("Baixar", "Download")`. Both
 * languages sit side by side where they're used, so a component's copy reads as one.
 */
export function pick(lang: Lang) {
  return <T,>(pt: T, en: T): T => (lang === "en" ? en : pt);
}
