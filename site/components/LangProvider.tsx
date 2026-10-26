"use client";

import { createContext, useContext, type ReactNode } from "react";
import { locale, pick, type Lang } from "@/lib/lang";

const LangContext = createContext<Lang>("pt");

/** The page's language, for the client components (demos, replicas) under it. */
export function LangProvider({ lang, children }: { lang: Lang; children: ReactNode }) {
  return <LangContext.Provider value={lang}>{children}</LangContext.Provider>;
}

export function useLang(): Lang {
  return useContext(LangContext);
}

/** `const l = useL(); l("Buscar", "Search")`, plus the locale tag for Intl formatting. */
export function useL() {
  const lang = useLang();
  return Object.assign(pick(lang), { lang, locale: locale[lang] });
}
