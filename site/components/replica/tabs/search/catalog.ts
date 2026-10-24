import {
  Activity,
  Bell,
  Book,
  Calculator,
  Calendar,
  Camera,
  ClipboardList,
  Cloud,
  Coffee,
  Compass,
  Copy,
  Equal,
  Flame,
  Flower2,
  Folder,
  Gift,
  Globe,
  Grid3x3,
  Hammer,
  Heart,
  Image,
  ListChecks,
  Lock,
  Mail,
  Map,
  MessageCircle,
  Moon,
  Music,
  PartyPopper,
  Pipette,
  Rocket,
  Settings,
  Smile,
  SquareTerminal,
  Star,
  StickyNote,
  Sun,
  TextAlignStart,
  Undo2,
  Video,
  Zap,
  type LucideIcon,
} from "lucide-react";
import { tabs, type TabId } from "../../tabs";

/** ToolPalette (Sources/Cleen/Components/ToolPalette.swift). */
export const palette = {
  blue: "rgb(10,133,255)",
  indigo: "rgb(89,87,214)",
  pink: "rgb(255,56,94)",
  orange: "rgb(255,148,0)",
  yellow: "rgb(245,184,0)",
  teal: "rgb(48,176,199)",
  gray: "rgb(143,143,148)",
  tab: "rgba(255,255,255,0.55)",
} as const;

/** A window's place on screen, as fractions of it: x, y, width, height. */
export type Region = readonly [number, number, number, number];

/** A Mac app's look for the drawn icon: a gradient square and a white (or dark) glyph. */
export type AppLook = { from: string; to: string; glyph: LucideIcon; ink?: string };

export type ItemIcon =
  | { kind: "symbol"; color: string; glyph: LucideIcon }
  | { kind: "window"; region: Region }
  | { kind: "app"; look: AppLook }
  | { kind: "emoji"; emoji: string }
  | { kind: "color"; hex: string }
  | { kind: "lucide"; glyph: LucideIcon };

/** What Return does: say what happened (the notch would close), or open a tab. */
export type Outcome = { kind: "done"; message: string } | { kind: "tab"; tab: TabId };

/** One row of the search (SearchItem). */
export type Item = {
  id: string;
  title: string;
  subtitle?: string;
  icon: ItemIcon;
  keywords?: readonly string[];
  /** The grey word on the right: "App", "Janela", "Comando". */
  kind?: string;
  outcome: Outcome;
};

export type Section = { title: string; items: Item[] };

const windowItem = (id: string, title: string, region: Region, keywords: readonly string[], message: string): Item => ({
  id: `window.${id}`,
  title,
  icon: { kind: "window", region },
  keywords,
  kind: "Janela",
  outcome: { kind: "done", message },
});

/** SearchCatalog.windows(), in the app's order. */
const windows: Item[] = [
  windowItem("leftHalf", "Metade esquerda", [0, 0, 0.5, 1], ["left half"], "Janela na metade esquerda"),
  windowItem("rightHalf", "Metade direita", [0.5, 0, 0.5, 1], ["right half"], "Janela na metade direita"),
  windowItem("topHalf", "Metade de cima", [0, 0, 1, 0.5], ["top half"], "Janela na metade de cima"),
  windowItem("bottomHalf", "Metade de baixo", [0, 0.5, 1, 0.5], ["bottom half"], "Janela na metade de baixo"),
  windowItem("maximize", "Maximizar", [0, 0, 1, 1], ["maximize", "fill", "tela cheia"], "Janela maximizada"),
  windowItem("almostMaximize", "Quase maximizar", [0.12, 0.14, 0.76, 0.72], ["almost maximize"], "Janela quase maximizada"),
  windowItem("center", "Centralizar", [0.25, 0.22, 0.5, 0.56], ["center"], "Janela no centro"),
  windowItem("topLeft", "Canto superior esquerdo", [0, 0, 0.5, 0.5], ["top left quarter"], "Janela no canto superior esquerdo"),
  windowItem("topRight", "Canto superior direito", [0.5, 0, 0.5, 0.5], ["top right quarter"], "Janela no canto superior direito"),
  windowItem("bottomLeft", "Canto inferior esquerdo", [0, 0.5, 0.5, 0.5], ["bottom left quarter"], "Janela no canto inferior esquerdo"),
  windowItem("bottomRight", "Canto inferior direito", [0.5, 0.5, 0.5, 0.5], ["bottom right quarter"], "Janela no canto inferior direito"),
  windowItem("firstThird", "Primeiro terço", [0, 0, 1 / 3, 1], ["first third"], "Janela no primeiro terço"),
  windowItem("centerThird", "Terço do meio", [1 / 3, 0, 1 / 3, 1], ["center third"], "Janela no terço do meio"),
  windowItem("lastThird", "Último terço", [2 / 3, 0, 1 / 3, 1], ["last third"], "Janela no último terço"),
  windowItem("firstTwoThirds", "Dois terços à esquerda", [0, 0, 2 / 3, 1], ["first two thirds"], "Janela em dois terços à esquerda"),
  windowItem("lastTwoThirds", "Dois terços à direita", [1 / 3, 0, 2 / 3, 1], ["last two thirds"], "Janela em dois terços à direita"),
  {
    id: "window.nextDisplay",
    title: "Próxima tela",
    icon: { kind: "symbol", color: palette.blue, glyph: Copy },
    keywords: ["next display", "move to next screen", "monitor"],
    kind: "Janela",
    outcome: { kind: "done", message: "Janela na próxima tela" },
  },
  {
    id: "window.restore",
    title: "Restaurar tamanho",
    icon: { kind: "symbol", color: palette.blue, glyph: Undo2 },
    keywords: ["restore"],
    kind: "Janela",
    outcome: { kind: "done", message: "Janela de volta ao tamanho de antes" },
  },
];

const command = (id: string, title: string, color: string, glyph: LucideIcon, keywords: readonly string[], outcome: Outcome, subtitle?: string): Item => ({
  id,
  title,
  subtitle,
  icon: { kind: "symbol", color, glyph },
  keywords,
  kind: "Comando",
  outcome,
});

const lorem = ["lorem ipsum", "placeholder", "texto"];

/** SearchCatalog.tools(): Cleen's own commands. */
const tools: Item[] = [
  command("tool.colorPicker", "Conta-gotas", palette.pink, Pipette, ["color picker", "cor", "pick color", "hex"], { kind: "done", message: "#0071E3 copiado" }, "Pega uma cor da tela e copia o hex"),
  command("tool.confetti", "Confete", palette.orange, PartyPopper, ["confetti", "celebrar", "festa"], { kind: "done", message: "Confete na tela" }),
  command("lorem.paragraph", "Lorem ipsum: 1 parágrafo", palette.gray, TextAlignStart, lorem, { kind: "done", message: "1 parágrafo colado" }),
  command("lorem.paragraphs", "Lorem ipsum: 3 parágrafos", palette.gray, TextAlignStart, lorem, { kind: "done", message: "3 parágrafos colados" }),
  command("lorem.sentence", "Lorem ipsum: 1 frase", palette.gray, TextAlignStart, lorem, { kind: "done", message: "1 frase colada" }),
  command("lorem.words", "Lorem ipsum: 10 palavras", palette.gray, TextAlignStart, lorem, { kind: "done", message: "10 palavras coladas" }),
  command("tool.emoji", "Buscar emoji", palette.yellow, Smile, ["emoji", "search emoji"], { kind: "tab", tab: "emoji" }),
  command("tool.clipboard", "Histórico da área de transferência", palette.indigo, ClipboardList, ["clipboard history", "copiados"], { kind: "done", message: "Histórico aberto" }),
  command("tool.icons", "Buscar ícones Lucide", palette.teal, Grid3x3, ["lucide", "icons", "ícones", "svg"], { kind: "tab", tab: "icons" }),
  command("system.lock", "Bloquear tela", palette.gray, Lock, ["lock screen"], { kind: "done", message: "Tela bloqueada" }),
  command("system.sleep", "Repouso", palette.gray, Moon, ["sleep", "dormir"], { kind: "done", message: "O Mac entrou em repouso" }),
];

/** SearchCatalog.tabs(): jump straight to a tab of the notch. */
const tabItems: Item[] = tabs.map((tab) => ({
  id: `tab.${tab.id}`,
  title: tab.id === "home" ? "Início" : tab.title,
  icon: { kind: "symbol", color: palette.tab, glyph: tab.icon },
  keywords: [tab.id],
  kind: "Cleen",
  outcome: { kind: "tab", tab: tab.id },
}));

const app = (name: string, look: AppLook, keywords: readonly string[] = []): Item => ({
  id: `app.${name}`,
  title: name,
  icon: { kind: "app", look },
  keywords,
  kind: "App",
  outcome: { kind: "done", message: `${name} aberto` },
});

/** A handful of the Mac's own apps, with the names Finder shows in Portuguese. */
const apps: Item[] = [
  app("Ajustes do Sistema", { from: "#a1a1a6", to: "#5b5b60", glyph: Settings }, ["system settings", "preferences"]),
  app("Calculadora", { from: "#6e6e73", to: "#2c2c2e", glyph: Calculator, ink: "#ff9f0a" }, ["calculator"]),
  app("Calendário", { from: "#ffffff", to: "#e5e5ea", glyph: Calendar, ink: "#ff3b30" }, ["calendar"]),
  app("FaceTime", { from: "#5de07a", to: "#1fae45", glyph: Video }),
  app("Finder", { from: "#6ac4ff", to: "#1a73e8", glyph: Smile }),
  app("Fotos", { from: "#ffd36b", to: "#ff7a45", glyph: Flower2 }, ["photos"]),
  app("Lembretes", { from: "#ffffff", to: "#e5e5ea", glyph: ListChecks, ink: "#0a84ff" }, ["reminders"]),
  app("Mail", { from: "#6ac4ff", to: "#0a6cff", glyph: Mail }),
  app("Mapas", { from: "#7ee08f", to: "#2fb35a", glyph: Map }, ["maps"]),
  app("Mensagens", { from: "#6ef07f", to: "#20c33d", glyph: MessageCircle }, ["messages"]),
  app("Monitor de Atividade", { from: "#3a3a3c", to: "#111113", glyph: Activity, ink: "#5cd685" }, ["activity monitor"]),
  app("Música", { from: "#ff6b81", to: "#f52d4b", glyph: Music }, ["music"]),
  app("Notas", { from: "#ffe27a", to: "#f5b800", glyph: StickyNote }, ["notes"]),
  app("Pré-Visualização", { from: "#8ad1ff", to: "#2a8cf0", glyph: Image }, ["preview"]),
  app("Safari", { from: "#5ac8fa", to: "#0a6cff", glyph: Compass }),
  app("Terminal", { from: "#48484a", to: "#1c1c1e", glyph: SquareTerminal }),
  app("Xcode", { from: "#5ab0ff", to: "#1662d6", glyph: Hammer }),
];

/** A few emoji with their Portuguese names (EmojiModel). */
const emoji: { emoji: string; name: string; keywords: readonly string[] }[] = [
  { emoji: "🔥", name: "fogo", keywords: ["chama", "fire"] },
  { emoji: "🎉", name: "confete", keywords: ["festa", "parabéns", "tada"] },
  { emoji: "🥳", name: "rosto festejando", keywords: ["festa", "aniversário"] },
  { emoji: "🎂", name: "bolo de aniversário", keywords: ["festa", "bolo"] },
  { emoji: "❤️", name: "coração vermelho", keywords: ["amor", "heart"] },
  { emoji: "🚀", name: "foguete", keywords: ["lançamento", "rocket"] },
  { emoji: "👍", name: "polegar para cima", keywords: ["joinha", "ok", "curtir"] },
  { emoji: "😂", name: "rosto chorando de rir", keywords: ["risada", "rir"] },
  { emoji: "✅", name: "marca de seleção", keywords: ["feito", "ok", "check"] },
  { emoji: "☕", name: "café", keywords: ["bebida quente", "coffee"] },
  { emoji: "⭐", name: "estrela", keywords: ["star"] },
  { emoji: "💡", name: "lâmpada", keywords: ["ideia"] },
  { emoji: "🙏", name: "mãos juntas", keywords: ["obrigado", "por favor"] },
  { emoji: "🌧️", name: "nuvem com chuva", keywords: ["chuva", "tempo"] },
  { emoji: "🍕", name: "pizza", keywords: ["comida"] },
  { emoji: "👀", name: "olhos", keywords: ["olhando"] },
];

/** A few Lucide icons, found by their English names and tags. */
const lucide: { name: string; glyph: LucideIcon; tags: readonly string[] }[] = [
  { name: "flame", glyph: Flame, tags: ["fire", "fogo", "hot"] },
  { name: "rocket", glyph: Rocket, tags: ["launch", "foguete"] },
  { name: "heart", glyph: Heart, tags: ["love", "like"] },
  { name: "star", glyph: Star, tags: ["favorite"] },
  { name: "sun", glyph: Sun, tags: ["weather", "light"] },
  { name: "cloud", glyph: Cloud, tags: ["weather"] },
  { name: "coffee", glyph: Coffee, tags: ["drink", "cafe"] },
  { name: "camera", glyph: Camera, tags: ["photo"] },
  { name: "gift", glyph: Gift, tags: ["present", "party", "festa"] },
  { name: "party-popper", glyph: PartyPopper, tags: ["party", "confetti", "festa"] },
  { name: "zap", glyph: Zap, tags: ["flash", "lightning"] },
  { name: "bell", glyph: Bell, tags: ["notification", "alarm"] },
  { name: "folder", glyph: Folder, tags: ["directory"] },
  { name: "globe", glyph: Globe, tags: ["world", "web"] },
  { name: "book", glyph: Book, tags: ["read", "notes"] },
  { name: "music", glyph: Music, tags: ["song", "musica"] },
];

// MARK: Matching (FuzzyMatch.swift)

export function fold(text: string): string {
  return text.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase();
}

function lengthPenalty(text: string, query: string) {
  return Math.min(0.1, Math.max(0, text.length - query.length) * 0.004);
}

function isSubsequence(needle: string, haystack: string) {
  let index = 0;
  for (const character of needle) {
    const found = haystack.indexOf(character, index);
    if (found < 0) return false;
    index = found + 1;
  }
  return true;
}

function score(rawQuery: string, candidate: string): number | null {
  const query = fold(rawQuery).trim();
  if (query.length === 0) return 0.5;
  const text = fold(candidate);
  if (text === query) return 1;
  if (text.startsWith(query)) return 0.95 - lengthPenalty(text, query);
  const words = text.split(/[^\p{L}\p{N}]+/u).filter(Boolean);
  if (words.some((word) => word.startsWith(query))) return 0.85 - lengthPenalty(text, query);
  const parts = query.split(" ").filter(Boolean);
  if (parts.length > 1 && parts.every((part) => words.some((word) => word.startsWith(part)))) return 0.8 - lengthPenalty(text, query);
  const initials = words.map((word) => word[0]).join("");
  if (query.length > 1 && initials.startsWith(query)) return 0.75;
  if (text.includes(query)) return 0.6 - lengthPenalty(text, query);
  if (isSubsequence(query.replaceAll(" ", ""), text)) return 0.3;
  return null;
}

function bestScore(query: string, title: string, keywords: readonly string[] = []): number | null {
  const scores = [score(query, title), ...keywords.map((keyword) => (score(query, keyword) ?? -1) * 0.9)].filter((value): value is number => value !== null && value >= 0);
  return scores.length > 0 ? Math.max(...scores) : null;
}

/** Best first; letters merely in order only count when nothing matches better. */
function rank(candidates: Item[], text: string): Item[] {
  const scored = candidates.flatMap((item) => {
    const match = bestScore(text, item.title, item.keywords);
    return match === null ? [] : [{ item, match }];
  });
  const strong = scored.filter(({ match }) => match >= 0.5);
  return (strong.length > 0 ? strong : scored).sort((a, b) => b.match - a.match).map(({ item }) => item);
}

// MARK: Calculator (Calculator.swift, with the Brazilian comma)

type Token = { kind: "number"; value: number } | { kind: "op"; op: string } | { kind: "open" } | { kind: "close" } | { kind: "percent" };

function parseNumber(raw: string): number | null {
  let text = raw;
  if (text.includes(",") && text.includes(".")) text = text.replaceAll(".", "");
  else if (text.split(".").length === 2 && text.length - text.indexOf(".") !== 4) text = text.replace(".", ",");
  else text = text.replaceAll(".", "");
  const value = Number(text.replace(",", "."));
  return Number.isFinite(value) ? value : null;
}

function tokenize(text: string): Token[] | null {
  const tokens: Token[] = [];
  let number = "";
  const flush = () => {
    if (number.length === 0) return true;
    const value = parseNumber(number);
    number = "";
    if (value === null) return false;
    tokens.push({ kind: "number", value });
    return true;
  };
  for (const character of text) {
    if (/[0-9.,]/.test(character)) {
      number += character;
      continue;
    }
    if (!flush()) return null;
    if (character === " ") continue;
    if ("+-*/^".includes(character)) tokens.push({ kind: "op", op: character });
    else if ("xX×".includes(character)) tokens.push({ kind: "op", op: "*" });
    else if (character === "÷") tokens.push({ kind: "op", op: "/" });
    else if (character === "(") tokens.push({ kind: "open" });
    else if (character === ")") tokens.push({ kind: "close" });
    else if (character === "%") tokens.push({ kind: "percent" });
    else return null;
  }
  return flush() ? tokens : null;
}

function evaluate(text: string): number | null {
  const tokens = tokenize(text);
  if (!tokens || !tokens.some((token) => token.kind === "op" || token.kind === "percent")) return null;
  let position = 0;
  const current = () => tokens[position];
  const isOp = (...ops: string[]) => {
    const token = current();
    return token?.kind === "op" && ops.includes(token.op) ? token.op : null;
  };

  const expression = (): number | null => {
    let value = term();
    if (value === null) return null;
    for (let op = isOp("+", "-"); op; op = isOp("+", "-")) {
      position += 1;
      let right = term();
      if (right === null) return null;
      // `200 + 15%` means 15% of 200, as on a calculator.
      if (current()?.kind === "percent") {
        position += 1;
        right = (value * right) / 100;
      }
      value = op === "+" ? value + right : value - right;
    }
    return value;
  };
  const term = (): number | null => {
    let value = power();
    if (value === null) return null;
    for (let op = isOp("*", "/"); op; op = isOp("*", "/")) {
      position += 1;
      const right = power();
      if (right === null || (op === "/" && right === 0)) return null;
      value = op === "*" ? value * right : value / right;
    }
    return value;
  };
  const power = (): number | null => {
    const base = unary();
    if (base === null) return null;
    if (isOp("^")) {
      position += 1;
      const exponent = power();
      return exponent === null ? null : base ** exponent;
    }
    return base;
  };
  const followsAddition = () => {
    const before = tokens[position - 2];
    return position >= 2 && before?.kind === "op" && (before.op === "+" || before.op === "-");
  };
  const unary = (): number | null => {
    if (isOp("-")) {
      position += 1;
      const value = unary();
      return value === null ? null : -value;
    }
    let value = primary();
    if (value === null) return null;
    if (current()?.kind === "percent" && !followsAddition()) {
      position += 1;
      value /= 100;
    }
    return value;
  };
  const primary = (): number | null => {
    const token = current();
    if (token?.kind === "number") {
      position += 1;
      return token.value;
    }
    if (token?.kind === "open") {
      position += 1;
      const value = expression();
      if (value === null || current()?.kind !== "close") return null;
      position += 1;
      return value;
    }
    return null;
  };

  const value = expression();
  return value !== null && position === tokens.length && Number.isFinite(value) ? value : null;
}

const decimal = new Intl.NumberFormat("pt-BR", { maximumFractionDigits: 10 });

function calculation(text: string): Item | null {
  const value = evaluate(text);
  if (value === null) return null;
  const result = decimal.format(value);
  return { id: "calc", title: result, subtitle: text, icon: { kind: "symbol", color: palette.orange, glyph: Equal }, kind: "Copiar", outcome: { kind: "done", message: `${result} copiado` } };
}

/** A hex color typed in: its swatch, to copy. */
function color(text: string): Item | null {
  const match = /^#?([0-9a-f]{3}|[0-9a-f]{6})$/i.exec(text);
  if (!match?.[1]) return null;
  const digits = match[1].length === 3 ? [...match[1]].map((digit) => digit + digit).join("") : match[1];
  const hex = `#${digits.toUpperCase()}`;
  const value = Number.parseInt(digits, 16);
  const rgb = `rgb(${(value >> 16) & 255}, ${(value >> 8) & 255}, ${value & 255})`;
  return { id: `color.${hex}`, title: hex, subtitle: rgb, icon: { kind: "color", hex }, kind: "Copiar", outcome: { kind: "done", message: `${hex} copiado` } };
}

function matches(text: string, ...fields: readonly string[]) {
  const query = fold(text);
  return fields.some((field) => fold(field).split(/\s+/).some((word) => word.startsWith(query)) || fold(field).includes(query));
}

// MARK: Results (SearchModel.recompute)

const commands = [...windows, ...tools, ...tabItems];
const byId = (id: string) => [...apps, ...commands].find((item) => item.id === id);

/** With nothing typed: what you run most, then a few starting points. */
function suggestions(): Section[] {
  const recent = ["app.Safari", "app.Notas"].flatMap((id) => byId(id) ?? []);
  const starters = ["window.leftHalf", "window.rightHalf", "window.maximize", "tool.colorPicker", "tool.clipboard", "tool.emoji"].flatMap((id) => byId(id) ?? []);
  return [
    { title: "Recentes", items: recent },
    { title: "Sugestões", items: starters.slice(0, 6 - Math.min(recent.length, 3)) },
  ];
}

/** The sections for a query, the way SearchModel builds them. */
export function results(query: string): Section[] {
  const text = query.trim();
  if (text.length === 0) return suggestions();
  const sections: Section[] = [];
  const calc = calculation(text);
  if (calc) sections.push({ title: "Calculadora", items: [calc] });
  const swatch = color(text);
  if (swatch) sections.push({ title: "Cor", items: [swatch] });
  const ranked = swatch ? [] : rank([...apps, ...commands], text);
  if (ranked.length > 0) sections.push({ title: "Resultados", items: ranked.slice(0, 12) });
  if (text.length >= 2 && !calc && !swatch) {
    const faces = emoji.filter((item) => matches(text, item.name, ...item.keywords)).slice(0, 4);
    if (faces.length > 0) sections.push({ title: "Emoji", items: faces.map((item) => ({ id: `emoji.${item.emoji}`, title: item.name, icon: { kind: "emoji", emoji: item.emoji }, kind: "Colar", outcome: { kind: "done", message: `${item.emoji} colado` } })) });
    const icons = lucide.filter((item) => matches(text, item.name, ...item.tags)).slice(0, 4);
    if (icons.length > 0) sections.push({ title: "Ícones Lucide", items: icons.map((item) => ({ id: `lucide.${item.name}`, title: item.name, icon: { kind: "lucide", glyph: item.glyph }, kind: "Copiar SVG", outcome: { kind: "done", message: `${item.name}.svg copiado` } })) });
  }
  return sections;
}
