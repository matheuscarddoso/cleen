import { Info, LayoutGrid, PanelTop, Settings, Sun, Trash2, type LucideIcon } from "lucide-react";
import { panel } from "../../style";

/** The pages of Ajustes (SettingsSection). */
export type SectionId = "general" | "displays" | "notch" | "tabs" | "cleaning" | "agents" | "about";

export type Section = { id: SectionId; title: string; subtitle: string; icon: LucideIcon | "claude" };

export const sections: Record<SectionId, Section> = {
  general: { id: "general", title: "Geral", subtitle: "Como o Cleen começa, onde aparece e quando avisa.", icon: Settings },
  displays: { id: "displays", title: "Telas", subtitle: "O brilho de cada tela, inclusive a do monitor externo.", icon: Sun },
  notch: { id: "notch", title: "Aparência", subtitle: "Como o notch abre e o que mostra fechado.", icon: PanelTop },
  tabs: { id: "tabs", title: "Abas", subtitle: "As ferramentas na barra do notch e a ordem delas.", icon: LayoutGrid },
  cleaning: { id: "cleaning", title: "Limpeza", subtitle: "O que conta como projeto parado e arquivo grande.", icon: Trash2 },
  agents: { id: "agents", title: "Claude Code", subtitle: "Os pedidos de permissão, respondidos no notch.", icon: "claude" },
  about: { id: "about", title: "Sobre", subtitle: "Permissões e o que o Cleen já fez.", icon: Info },
};

/** Sidebar headings, as in the app: none over the first pair, then NOTCH, FERRAMENTAS, CLEEN. */
export const sidebar: { title: string | null; sections: SectionId[] }[] = [
  { title: null, sections: ["general", "displays"] },
  { title: "Notch", sections: ["notch", "tabs"] },
  { title: "Ferramentas", sections: ["cleaning", "agents"] },
  { title: "Cleen", sections: ["about"] },
];

/** NotchSettings.widths / heights, in points of the real panel. */
export const widths = [
  { label: "Padrão", value: 680 },
  { label: "Largo", value: 780 },
  { label: "Extra", value: 880 },
] as const;
export const heights = [
  { label: "Padrão", value: 234 },
  { label: "Alto", value: 274 },
  { label: "Mais alto", value: 314 },
] as const;

/**
 * The size the replica can actually take. The demo canvas is 760 wide, so the real
 * 780 and 880 would spill over it: Largo shows at 730 and Extra at 760, still clearly
 * growing step by step. Heights fit as they are.
 */
export function shownSize(width: number, height: number) {
  const shownWidth = width >= 880 ? 760 : width >= 780 ? 730 : panel.width;
  return { width: shownWidth, height: Math.max(panel.height, Math.min(314, height)) };
}

export type Idle = "disk" | "battery" | "cpu" | "none";

/** Ajustes › Aparência, both groups: NotchAppearanceSettings and ClosedNotchSettings. */
export type Appearance = {
  hover: boolean;
  delay: number;
  gestures: boolean;
  width: number;
  height: number;
  allScreens: boolean;
  wings: boolean;
  idle: Idle;
  power: boolean;
  headphones: boolean;
  track: boolean;
  meeting: boolean;
  agents: boolean;
  hideInFullscreen: boolean;
  mediaKeys: boolean;
};

export const appearanceDefaults: Appearance = {
  hover: true,
  delay: 0,
  gestures: true,
  width: panel.width,
  height: panel.height,
  allScreens: false,
  wings: true,
  idle: "disk",
  power: true,
  headphones: true,
  track: true,
  meeting: true,
  agents: true,
  hideInFullscreen: true,
  mediaKeys: false,
};

/** The two screens of Ajustes › Telas, 0…1. */
export type Displays = { builtIn: number; external: number };

export const displaysDefaults: Displays = { builtIn: 0.67, external: 1 };

/** Where the Aparência script keeps the page scrolled: the top, or the size rows. */
export type Scroll = "top" | "size";

type Beat<T> = { ms: number; set: Partial<T>; scroll?: Scroll };

/**
 * Aparência: the delay walks Nenhum → Longo, opening flips to a click (Atraso folds
 * away) and back, the trackpad switch goes off and on, then the page scrolls to the
 * size rows and the whole panel grows wider, then taller, and settles back.
 */
export const appearanceScript: Beat<Appearance>[] = [
  { ms: 2200, set: {} },
  { ms: 950, set: { delay: 0.12 } },
  { ms: 950, set: { delay: 0.3 } },
  { ms: 1500, set: { delay: 0.6 } },
  { ms: 1900, set: { hover: false, delay: 0.6 } },
  { ms: 1500, set: { delay: 0 } },
  { ms: 1300, set: { gestures: false } },
  { ms: 1100, set: {} },
  { ms: 1100, set: {}, scroll: "size" },
  { ms: 1900, set: { width: 780 }, scroll: "size" },
  { ms: 1900, set: { width: 880 }, scroll: "size" },
  { ms: 1900, set: { width: 880, height: 274 }, scroll: "size" },
  { ms: 2100, set: { width: 880, height: 314 }, scroll: "size" },
  { ms: 1500, set: {}, scroll: "size" },
  { ms: 1200, set: {} },
];

/** Telas: the Mac's own screen dims and brightens, then the monitor does the same. */
export const displaysScript: Beat<Displays>[] = [
  { ms: 1900, set: {} },
  { ms: 1500, set: { builtIn: 0.3 } },
  { ms: 1500, set: { builtIn: 0.86 } },
  { ms: 1500, set: { builtIn: 0.86, external: 0.45 } },
  { ms: 1500, set: { builtIn: 0.86, external: 0.8 } },
  { ms: 1700, set: { external: 1 } },
];

/** The state at a beat: the defaults with that beat's changes. */
export function at<T>(script: Beat<T>[], defaults: T, step: number): { state: T; scroll: Scroll } {
  const beat = script[step] ?? script[0];
  return { state: { ...defaults, ...beat?.set }, scroll: beat?.scroll ?? "top" };
}
