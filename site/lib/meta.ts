import type { Metadata, Viewport } from "next";
import { home, locale, pick, type Lang } from "./lang";
import { site } from "./site";

/** Title, description, share card and the pointers between the two languages. */
export function metadataFor(lang: Lang): Metadata {
  const l = pick(lang);
  const title = l("Cleen — Tudo no notch.", "Cleen — Everything in the notch.");
  const description = l(
    "O Cleen mora no notch do seu Mac: limpa o disco, move janelas, cola emoji, mostra o Claude Code trabalhando e traz quase trinta ferramentas a um gesto. Grátis.",
    "Cleen lives in your Mac’s notch: it cleans up your disk, moves windows, pastes emoji, shows Claude Code at work and puts nearly thirty tools one gesture away. Free.",
  );
  const image = { url: l("/cleen-og.png?v=3", "/cleen-og-en.png?v=1"), width: 1200, height: 630, alt: l("O painel do Cleen aberto no notch de um Mac", "Cleen’s panel open in a Mac’s notch") };
  return {
    metadataBase: new URL(site.url),
    title: { default: title, template: "%s · Cleen" },
    description,
    applicationName: site.name,
    authors: [{ name: site.author, url: site.authorUrl }],
    alternates: { canonical: home[lang], languages: { "pt-BR": home.pt, en: home.en, "x-default": home.pt } },
    icons: { icon: "/cleen-favicon.png", apple: "/cleen-apple-touch-icon.png" },
    openGraph: {
      type: "website",
      url: new URL(home[lang], site.url).toString(),
      siteName: site.name,
      title,
      description,
      locale: locale[lang].replace("-", "_"),
      alternateLocale: [locale[lang === "pt" ? "en" : "pt"].replace("-", "_")],
      images: [image],
    },
    twitter: { card: "summary_large_image", title, description, images: [image.url] },
  };
}

export const viewport: Viewport = { themeColor: "#f5f5f7", colorScheme: "light" };
