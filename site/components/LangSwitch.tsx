"use client";

import { home, langCookie, type Lang } from "@/lib/lang";
import { useLang } from "./LangProvider";

const names: Record<Lang, string> = { pt: "Português", en: "English" };

/** Português · English, in the footer. The pick is remembered and wins from then on. */
export function LangSwitch() {
  const current = useLang();
  return (
    <nav aria-label="Idioma / Language" className="flex items-center gap-2">
      {(["pt", "en"] as const).map((lang, index) => (
        <span key={lang} className="flex items-center gap-2">
          {index > 0 && <span aria-hidden>·</span>}
          {lang === current ? (
            <span aria-current="page" className="text-ink">
              {names[lang]}
            </span>
          ) : (
            <a
              href={home[lang]}
              hrefLang={lang === "pt" ? "pt-BR" : "en"}
              lang={lang === "pt" ? "pt-BR" : "en"}
              className="hover:underline"
              onClick={() => {
                document.cookie = `${langCookie}=${lang}; path=/; max-age=31536000; samesite=lax`;
              }}
            >
              {names[lang]}
            </a>
          )}
        </span>
      ))}
    </nav>
  );
}
