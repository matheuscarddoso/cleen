import type { MetadataRoute } from "next";
import { home } from "@/lib/lang";
import { site } from "@/lib/site";

export default function sitemap(): MetadataRoute.Sitemap {
  const languages = { "pt-BR": new URL(home.pt, site.url).toString(), en: new URL(home.en, site.url).toString() };
  return [
    { url: languages["pt-BR"], changeFrequency: "monthly", priority: 1, alternates: { languages } },
    { url: languages.en, changeFrequency: "monthly", priority: 0.9, alternates: { languages } },
  ];
}
