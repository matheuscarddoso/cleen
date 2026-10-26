import {
  ArrowLeftRight,
  ChartLine,
  ChartNoAxesColumn,
  CloudSun,
  Grid3x3,
  HardDrive,
  LayoutGrid,
  Smile,
  Timer,
  type LucideIcon,
} from "lucide-react";
import type { Lang } from "@/lib/lang";

/** The tools the site's replica can open, in the tab bar's order. */
export type TabId = "home" | "timer" | "weather" | "stocks" | "converter" | "emoji" | "icons" | "overview" | "system";

/** What the panel is showing: a tool with the tab bar, the search, or Ajustes. */
export type Mode = "tool" | "search" | "settings";

/** `title` is the app's Portuguese (NotchTab.title); `en` its English, from Localizable.strings. */
export const tabs: { id: TabId; title: string; en: string; icon: LucideIcon }[] = [
  { id: "home", title: "Cleen", en: "Cleen", icon: LayoutGrid },
  { id: "timer", title: "Timer", en: "Timer", icon: Timer },
  { id: "weather", title: "Tempo", en: "Weather", icon: CloudSun },
  { id: "stocks", title: "Ações", en: "Stocks", icon: ChartLine },
  { id: "converter", title: "Conversor", en: "Converter", icon: ArrowLeftRight },
  { id: "emoji", title: "Emoji", en: "Emoji", icon: Smile },
  { id: "icons", title: "Ícones", en: "Icons", icon: Grid3x3 },
  { id: "overview", title: "Visão geral", en: "Overview", icon: HardDrive },
  { id: "system", title: "Sistema", en: "System", icon: ChartNoAxesColumn },
];

export function tabTitle(id: TabId, lang: Lang = "pt"): string {
  const tab = tabs.find((candidate) => candidate.id === id);
  if (!tab) return "Cleen";
  return lang === "en" ? tab.en : tab.title;
}
