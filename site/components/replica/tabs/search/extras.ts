import {
  ArrowUpFromLine,
  Compass,
  EyeOff,
  FileText,
  Globe,
  Hammer,
  Image,
  Link2,
  LogOut,
  Mail,
  PenTool,
  Power,
  RotateCcw,
  SquareTerminal,
  SquareX,
  SunMoon,
  Table,
  TextQuote,
  Trash2,
  Video,
  type LucideIcon,
} from "lucide-react";
import type { AppLook, Item, Outcome } from "./catalog";

/** ToolPalette, repeated here so this file stands alone. */
const blue = "rgb(10,133,255)";
const indigo = "rgb(89,87,214)";
const purple = "rgb(175,82,222)";
const gray = "rgb(143,143,148)";
const red = "rgb(255,69,58)";
const green = "rgb(52,199,89)";

const looks = {
  safari: { from: "#5ac8fa", to: "#0a6cff", glyph: Compass },
  xcode: { from: "#5ab0ff", to: "#1662d6", glyph: Hammer },
  terminal: { from: "#48484a", to: "#1c1c1e", glyph: SquareTerminal },
  figma: { from: "#3a3a3c", to: "#1c1c1e", glyph: PenTool, ink: "#a259ff" },
  mail: { from: "#6ac4ff", to: "#0a6cff", glyph: Mail },
} satisfies Record<string, AppLook>;

/** Open windows, by app and title: Return brings that one window to the front. */
export const openWindows: Item[] = [
  { app: "Figma", title: "Landing do Cleen — Rascunhos", look: looks.figma },
  { app: "Safari", title: "Cleen — Tudo no notch", look: looks.safari },
  { app: "Safari", title: "Frankfurter — câmbio do dia", look: looks.safari },
  { app: "Xcode", title: "Cleen — NotchSearchView.swift", look: looks.xcode },
  { app: "Terminal", title: "~/Projetos/site — zsh", look: looks.terminal },
  { app: "Mail", title: "Caixa de Entrada — 3 não lidas", look: looks.mail },
].map(({ app, title, look }) => ({
  id: `openWindow.${app}.${title}`,
  title,
  subtitle: app,
  icon: { kind: "app", look },
  keywords: [app],
  kind: "Janela aberta",
  verb: "Ir para a janela",
  outcome: { kind: "done", message: `${app} na frente, na janela certa` },
}));

/** Files the Spotlight index finds: the folder under the name, the kind on the right. */
export const files: Item[] = [
  { name: "Orçamento 2027.numbers", folder: "~/Documentos", tag: "NUM", color: green, keywords: ["orcamento", "planilha", "budget"] },
  { name: "Contrato do estúdio.pdf", folder: "~/Downloads", tag: "PDF", color: red, keywords: ["contrato"] },
  { name: "capa-landing.png", folder: "~/Desktop", tag: "PNG", color: blue, keywords: ["imagem", "capa"] },
  { name: "Roteiro do vídeo.pages", folder: "~/Documentos/Vídeos", tag: "DOC", color: "rgb(255,149,0)", keywords: ["roteiro", "teleprompter"] },
  { name: "README.md", folder: "~/Projetos/cleen", tag: "MD", color: gray, keywords: ["leia-me", "cleen"] },
].map(({ name, folder, tag, color, keywords }) => ({
  id: `file.${name}`,
  title: name,
  subtitle: folder,
  icon: { kind: "file", tag, color },
  keywords,
  kind: "Arquivo",
  outcome: { kind: "done", message: `${name} aberto` },
}));

/** Today's calendar: a meeting with a link joins it, anything else opens it. */
export const events: Item[] = [
  { title: "Daily do time", time: "09:30 – 09:45", link: true, keywords: ["reuniao", "daily", "meet"] },
  { title: "Revisão de design", time: "14:00 – 15:00", link: true, keywords: ["reuniao", "design", "review", "zoom"] },
  { title: "Dentista", time: "18:30 – 19:15", link: false, keywords: ["consulta"] },
].map(({ title, time, link, keywords }) => ({
  id: `event.${title}`,
  title,
  subtitle: time,
  icon: link ? { kind: "symbol", color: purple, glyph: Video } : { kind: "event", color: purple },
  keywords: [...keywords, "agenda", "hoje", "calendario"],
  kind: link ? "Entrar na reunião" : "Evento",
  verb: link ? "Entrar na reunião" : "Abrir no Calendário",
  outcome: { kind: "done", message: link ? `Entrando em ${title}` : `${title} aberto no Calendário` },
}));

/** Snippets: picked here, or typed anywhere by their keyword and expanded in place. */
export const snippets: Item[] = [
  { keyword: ";email", name: "E-mail de trabalho", text: "oi@exemplo.com" },
  { keyword: ";end", name: "Endereço de entrega", text: "Rua das Flores, 120, São Paulo" },
  { keyword: ";obg", name: "Agradecimento", text: "Valeu! Qualquer coisa, é só chamar." },
  { keyword: ";call", name: "Link da minha sala", text: "meet.exemplo.com/sala" },
].map(({ keyword, name, text }) => ({
  id: `snippet.${keyword}`,
  title: name,
  subtitle: text,
  icon: { kind: "symbol", color: indigo, glyph: TextQuote },
  keywords: [keyword, "snippet", "texto"],
  alias: keyword,
  kind: "Colar",
  outcome: { kind: "done", message: `“${text}” colado` },
}));

/** Quicklinks: an alias, then whatever's typed goes into the address as `{query}`. */
const quicklinks = [
  { alias: "gh", name: "GitHub", url: "github.com/search?q=" },
  { alias: "g", name: "Google", url: "google.com/search?q=" },
  { alias: "yt", name: "YouTube", url: "youtube.com/results?search_query=" },
  { alias: "mdn", name: "MDN", url: "developer.mozilla.org/search?q=" },
] as const;

export function quicklink(text: string): Item | null {
  const [alias, ...rest] = text.trim().split(/\s+/);
  const link = quicklinks.find((candidate) => candidate.alias === alias?.toLowerCase());
  const query = rest.join(" ");
  if (!link || query.length === 0) return null;
  return {
    id: `quicklink.${link.alias}`,
    title: `Buscar “${query}” no ${link.name}`,
    subtitle: `${link.url}${encodeURIComponent(query)}`,
    icon: { kind: "symbol", color: blue, glyph: Link2 },
    alias: link.alias,
    kind: "Link rápido",
    verb: "Abrir",
    outcome: { kind: "done", message: `${link.name} aberto com “${query}”` },
  };
}

/** Nothing matched: take the words to the web instead of a dead end. */
export function webFallback(text: string): Item {
  const query = text.trim();
  return {
    id: "web.google",
    title: `Buscar “${query}” na web`,
    subtitle: "Google",
    icon: { kind: "symbol", color: blue, glyph: Globe },
    kind: "Na web",
    verb: "Buscar",
    outcome: { kind: "done", message: `Buscando “${query}” no navegador` },
  };
}

/** Things copied before, matched by their text. */
export const clipboard: Item[] = [
  { text: "https://cleen.ocardoso.com", from: "Safari" },
  { text: "npm run dev -- --port 3000", from: "Terminal" },
  { text: "Reunião passou para as 14h, sala 3", from: "Mensagens" },
].map(({ text, from }) => ({
  id: `clip.${text}`,
  title: text,
  subtitle: from,
  icon: { kind: "symbol", color: indigo, glyph: text.startsWith("http") ? Link2 : FileText },
  kind: "Colar",
  outcome: { kind: "done", message: "Colado onde você estava" },
}));

const system = (id: string, title: string, glyph: LucideIcon, keywords: string[], outcome: Outcome): Item => ({
  id: `system.${id}`,
  title,
  icon: { kind: "symbol", color: gray, glyph },
  keywords,
  kind: "Comando",
  outcome,
});

/** The Mac's own commands, besides Bloquear tela and Repouso. */
export const systemCommands: Item[] = [
  system("restart", "Reiniciar", RotateCcw, ["restart", "reboot"], { kind: "done", message: "Reiniciando: os apps fecham primeiro" }),
  system("shutdown", "Desligar", Power, ["shut down", "desligar"], { kind: "done", message: "Desligando o Mac" }),
  system("logout", "Encerrar sessão", LogOut, ["log out", "sair da conta"], { kind: "done", message: "Encerrando a sessão" }),
  system("darkMode", "Alternar modo escuro", SunMoon, ["dark mode", "tema", "escuro", "claro"], { kind: "done", message: "Modo escuro ligado" }),
  system("hideAll", "Ocultar todos os apps", EyeOff, ["hide all apps", "mesa limpa"], { kind: "done", message: "Só a mesa, nada na frente" }),
  system("quitAll", "Sair de todos os apps", SquareX, ["quit all apps", "fechar tudo"], { kind: "done", message: "Todos os apps fechados" }),
  system("eject", "Ejetar todos os discos", ArrowUpFromLine, ["eject", "pendrive", "hd externo"], { kind: "done", message: "Pode desconectar os discos" }),
  {
    id: "system.emptyTrash",
    title: "Esvaziar o Lixo",
    icon: { kind: "symbol", color: gray, glyph: Trash2 },
    keywords: ["empty trash", "lixeira", "limpar lixo"],
    kind: "Comando",
    outcome: {
      kind: "review",
      outcome: "delete",
      items: [
        { name: "Gravação de tela 2026-10-02.mov", detail: "Apagado de ~/Desktop", size: 1.84e9, icon: Video },
        { name: "Instalador antigo.dmg", detail: "Apagado de ~/Downloads", size: 612e6, icon: ArrowUpFromLine },
        { name: "fotos-evento", detail: "Pasta com 148 fotos", size: 431e6, icon: Image },
        { name: "planilha (cópia).numbers", detail: "Apagado de ~/Documentos", size: 2.1e6, icon: Table },
      ],
      message: "Lixo esvaziado: 2,89 GB de volta",
    },
  },
];

/** Aliases and global shortcuts the person gave to commands (Ajustes › Busca). */
export const personal: Record<string, { alias?: string; hotkey?: readonly string[] }> = {
  "tool.clipboard": { alias: "cl", hotkey: ["⌃", "⌥", "V"] },
  "tool.emoji": { alias: "em", hotkey: ["⌃", "⌥", "E"] },
  "tool.colorPicker": { alias: "cor" },
  "window.leftHalf": { hotkey: ["⌃", "⌥", "←"] },
  "window.rightHalf": { hotkey: ["⌃", "⌥", "→"] },
  "window.maximize": { hotkey: ["⌃", "⌥", "↩"] },
  "system.darkMode": { alias: "dk" },
};
