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

/** The tools the site's replica can open, in the tab bar's order. */
export type TabId = "home" | "timer" | "weather" | "stocks" | "converter" | "emoji" | "icons" | "overview" | "system";

/** What the panel is showing: a tool with the tab bar, the search, or Ajustes. */
export type Mode = "tool" | "search" | "settings";

export const tabs: { id: TabId; title: string; icon: LucideIcon }[] = [
  { id: "home", title: "Cleen", icon: LayoutGrid },
  { id: "timer", title: "Timer", icon: Timer },
  { id: "weather", title: "Tempo", icon: CloudSun },
  { id: "stocks", title: "Ações", icon: ChartLine },
  { id: "converter", title: "Conversor", icon: ArrowLeftRight },
  { id: "emoji", title: "Emoji", icon: Smile },
  { id: "icons", title: "Ícones", icon: Grid3x3 },
  { id: "overview", title: "Visão geral", icon: HardDrive },
  { id: "system", title: "Sistema", icon: ChartNoAxesColumn },
];

export function tabTitle(id: TabId): string {
  return tabs.find((tab) => tab.id === id)?.title ?? "Cleen";
}
