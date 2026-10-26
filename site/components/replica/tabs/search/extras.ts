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
import { pick, type Lang } from "@/lib/lang";
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

/** Builds a list once per language: the copy changes, the shape doesn't. */
function perLang<T>(build: (lang: Lang) => T): (lang?: Lang) => T {
  const cache = new Map<Lang, T>();
  return (lang = "pt") => {
    if (!cache.has(lang)) cache.set(lang, build(lang));
    return cache.get(lang)!;
  };
}

/** Open windows, by app and title: Return brings that one window to the front. */
export const openWindows = perLang((lang): Item[] => {
  const l = pick(lang);
  return [
    { app: "Figma", title: l("Landing do Cleen — Rascunhos", "Cleen Landing — Drafts"), look: looks.figma },
    { app: "Safari", title: l("Cleen — Tudo no notch", "Cleen — Everything in the notch"), look: looks.safari },
    { app: "Safari", title: l("Frankfurter — câmbio do dia", "Frankfurter — today’s exchange rates"), look: looks.safari },
    { app: "Xcode", title: "Cleen — NotchSearchView.swift", look: looks.xcode },
    { app: "Terminal", title: l("~/Projetos/site — zsh", "~/Projects/site — zsh"), look: looks.terminal },
    { app: "Mail", title: l("Caixa de Entrada — 3 não lidas", "Inbox — 3 unread"), look: looks.mail },
  ].map(({ app, title, look }) => ({
    id: `openWindow.${app}.${title}`,
    title,
    subtitle: app,
    icon: { kind: "app", look },
    keywords: [app],
    kind: l("Janela aberta", "Open window"),
    verb: l("Ir para a janela", "Go to Window"),
    outcome: { kind: "done", message: l(`${app} na frente, na janela certa`, `${app} window brought to the front`) },
  }));
});

/** Files the Spotlight index finds: the folder under the name, the kind on the right. */
export const files = perLang((lang): Item[] => {
  const l = pick(lang);
  return [
    { name: l("Orçamento 2027.numbers", "Budget 2027.numbers"), folder: l("~/Documentos", "~/Documents"), tag: "NUM", color: green, keywords: l(["orcamento", "planilha", "budget"], ["spreadsheet", "finances"]) },
    { name: l("Contrato do estúdio.pdf", "Studio contract.pdf"), folder: "~/Downloads", tag: "PDF", color: red, keywords: l(["contrato"], ["agreement"]) },
    { name: l("capa-landing.png", "landing-cover.png"), folder: "~/Desktop", tag: "PNG", color: blue, keywords: l(["imagem", "capa"], ["image", "cover"]) },
    { name: l("Roteiro do vídeo.pages", "Video script.pages"), folder: l("~/Documentos/Vídeos", "~/Documents/Videos"), tag: "DOC", color: "rgb(255,149,0)", keywords: l(["roteiro", "teleprompter"], ["script", "teleprompter"]) },
    { name: "README.md", folder: l("~/Projetos/cleen", "~/Projects/cleen"), tag: "MD", color: gray, keywords: l(["leia-me", "cleen"], ["readme", "cleen"]) },
  ].map(({ name, folder, tag, color, keywords }) => ({
    id: `file.${name}`,
    title: name,
    subtitle: folder,
    icon: { kind: "file", tag, color },
    keywords,
    kind: l("Arquivo", "File"),
    verb: l("Abrir", "Open"),
    outcome: { kind: "done", message: l(`${name} aberto`, `${name} opened`) },
  }));
});

/** Today's calendar: a meeting with a link joins it, anything else opens it. */
export const events = perLang((lang): Item[] => {
  const l = pick(lang);
  return [
    { title: l("Daily do time", "Team daily"), time: l("09:30 – 09:45", "9:30 – 9:45 AM"), link: true, keywords: l(["reuniao", "daily", "meet"], ["meeting", "daily", "standup", "meet"]) },
    { title: l("Revisão de design", "Design review"), time: l("14:00 – 15:00", "2:00 – 3:00 PM"), link: true, keywords: l(["reuniao", "design", "review", "zoom"], ["meeting", "design", "review", "zoom"]) },
    { title: l("Dentista", "Dentist"), time: l("18:30 – 19:15", "6:30 – 7:15 PM"), link: false, keywords: l(["consulta"], ["appointment"]) },
  ].map(({ title, time, link, keywords }) => ({
    id: `event.${title}`,
    title,
    subtitle: time,
    icon: link ? { kind: "symbol", color: purple, glyph: Video } : { kind: "event", color: purple },
    keywords: [...keywords, ...l(["agenda", "hoje", "calendario"], ["schedule", "today", "calendar"])],
    kind: link ? l("Entrar na reunião", "Join Meeting") : l("Evento", "Event"),
    verb: link ? l("Entrar na reunião", "Join Meeting") : l("Abrir no Calendário", "Open in Calendar"),
    outcome: { kind: "done", message: link ? l(`Entrando em ${title}`, `Joining ${title}`) : l(`${title} aberto no Calendário`, `${title} opened in Calendar`) },
  }));
});

/** Snippets: picked here, or typed anywhere by their keyword and expanded in place. */
export const snippets = perLang((lang): Item[] => {
  const l = pick(lang);
  return l(
    [
      { keyword: ";email", name: "E-mail de trabalho", text: "oi@exemplo.com" },
      { keyword: ";end", name: "Endereço de entrega", text: "Rua das Flores, 120, São Paulo" },
      { keyword: ";obg", name: "Agradecimento", text: "Valeu! Qualquer coisa, é só chamar." },
      { keyword: ";call", name: "Link da minha sala", text: "meet.exemplo.com/sala" },
    ],
    [
      { keyword: ";email", name: "Work email", text: "hi@example.com" },
      { keyword: ";addr", name: "Shipping address", text: "120 Flower St, San Francisco" },
      { keyword: ";ty", name: "Thank-you note", text: "Thanks! Let me know if you need anything." },
      { keyword: ";call", name: "My meeting room", text: "meet.example.com/room" },
    ],
  ).map(({ keyword, name, text }) => ({
    id: `snippet.${keyword}`,
    title: name,
    subtitle: text,
    icon: { kind: "symbol", color: indigo, glyph: TextQuote },
    keywords: [keyword, "snippet", l("texto", "text")],
    alias: keyword,
    kind: l("Colar", "Paste"),
    outcome: { kind: "done", message: l(`“${text}” colado`, `“${text}” pasted`) },
  }));
});

/** Quicklinks: an alias, then whatever's typed goes into the address as `{query}`. */
const quicklinks = [
  { alias: "gh", name: "GitHub", url: "github.com/search?q=" },
  { alias: "g", name: "Google", url: "google.com/search?q=" },
  { alias: "yt", name: "YouTube", url: "youtube.com/results?search_query=" },
  { alias: "mdn", name: "MDN", url: "developer.mozilla.org/search?q=" },
] as const;

export function quicklink(text: string, lang: Lang = "pt"): Item | null {
  const l = pick(lang);
  const [alias, ...rest] = text.trim().split(/\s+/);
  const link = quicklinks.find((candidate) => candidate.alias === alias?.toLowerCase());
  const query = rest.join(" ");
  if (!link || query.length === 0) return null;
  return {
    id: `quicklink.${link.alias}`,
    title: l(`Buscar “${query}” no ${link.name}`, `Search ${link.name} for “${query}”`),
    subtitle: `${link.url}${encodeURIComponent(query)}`,
    icon: { kind: "symbol", color: blue, glyph: Link2 },
    alias: link.alias,
    kind: l("Link rápido", "Quicklink"),
    verb: l("Abrir", "Open"),
    outcome: { kind: "done", message: l(`${link.name} aberto com “${query}”`, `${link.name} opened for “${query}”`) },
  };
}

/** Nothing matched: take the words to the web instead of a dead end. */
export function webFallback(text: string, lang: Lang = "pt"): Item {
  const l = pick(lang);
  const query = text.trim();
  return {
    id: "web.google",
    title: l(`Buscar “${query}” na web`, `Search the web for “${query}”`),
    subtitle: "Google",
    icon: { kind: "symbol", color: blue, glyph: Globe },
    kind: l("Na web", "Web"),
    verb: l("Buscar", "Search"),
    outcome: { kind: "done", message: l(`Buscando “${query}” no navegador`, `Searching for “${query}” in the browser`) },
  };
}

/** Things copied before, matched by their text. */
export const clipboard = perLang((lang): Item[] => {
  const l = pick(lang);
  return [
    { text: "https://cleen.ocardoso.com", from: "Safari" },
    { text: "npm run dev -- --port 3000", from: "Terminal" },
    { text: l("Reunião passou para as 14h, sala 3", "Meeting moved to 2 PM, room 3"), from: l("Mensagens", "Messages") },
  ].map(({ text, from }) => ({
    id: `clip.${text}`,
    title: text,
    subtitle: from,
    icon: { kind: "symbol", color: indigo, glyph: text.startsWith("http") ? Link2 : FileText },
    kind: l("Colar", "Paste"),
    outcome: { kind: "done", message: l("Colado onde você estava", "Pasted where you were") },
  }));
});

/** The Mac's own commands, besides Lock Screen and Sleep. */
export const systemCommands = perLang((lang): Item[] => {
  const l = pick(lang);
  const command = l("Comando", "Command");
  const system = (id: string, title: string, glyph: LucideIcon, keywords: string[], outcome: Outcome): Item => ({
    id: `system.${id}`,
    title,
    icon: { kind: "symbol", color: gray, glyph },
    keywords,
    kind: command,
    outcome,
  });
  return [
    system("restart", l("Reiniciar", "Restart"), RotateCcw, ["restart", "reboot"], { kind: "done", message: l("Reiniciando: os apps fecham primeiro", "Restarting: apps quit first") }),
    system("shutdown", l("Desligar", "Shut Down"), Power, ["shut down", "desligar"], { kind: "done", message: l("Desligando o Mac", "Shutting down the Mac") }),
    system("logout", l("Encerrar sessão", "Log Out"), LogOut, ["log out", "sair da conta"], { kind: "done", message: l("Encerrando a sessão", "Logging out") }),
    system("darkMode", l("Alternar modo escuro", "Toggle Dark Mode"), SunMoon, ["dark mode", "tema", "escuro", "claro"], { kind: "done", message: l("Modo escuro ligado", "Dark mode on") }),
    system("hideAll", l("Ocultar todos os apps", "Hide All Apps"), EyeOff, ["hide all apps", "mesa limpa"], { kind: "done", message: l("Só a mesa, nada na frente", "Just the desktop, nothing in front") }),
    system("quitAll", l("Sair de todos os apps", "Quit All Apps"), SquareX, ["quit all apps", "fechar tudo"], { kind: "done", message: l("Todos os apps fechados", "All apps quit") }),
    system("eject", l("Ejetar todos os discos", "Eject All Disks"), ArrowUpFromLine, ["eject", "pendrive", "hd externo"], { kind: "done", message: l("Pode desconectar os discos", "Safe to unplug the disks") }),
    {
      id: "system.emptyTrash",
      title: l("Esvaziar o Lixo", "Empty Trash"),
      icon: { kind: "symbol", color: gray, glyph: Trash2 },
      keywords: ["empty trash", "lixeira", "limpar lixo"],
      kind: command,
      outcome: {
        kind: "review",
        outcome: "delete",
        items: [
          { name: l("Gravação de tela 2026-10-02.mov", "Screen Recording 2026-10-02.mov"), detail: l("Apagado de ~/Desktop", "Deleted from ~/Desktop"), size: 1.84e9, icon: Video },
          { name: l("Instalador antigo.dmg", "Old installer.dmg"), detail: l("Apagado de ~/Downloads", "Deleted from ~/Downloads"), size: 612e6, icon: ArrowUpFromLine },
          { name: l("fotos-evento", "event-photos"), detail: l("Pasta com 148 fotos", "Folder with 148 photos"), size: 431e6, icon: Image },
          { name: l("planilha (cópia).numbers", "spreadsheet copy.numbers"), detail: l("Apagado de ~/Documentos", "Deleted from ~/Documents"), size: 2.1e6, icon: Table },
        ],
        message: l("Lixo esvaziado: 2,89 GB de volta", "Trash emptied: 2.89 GB back"),
      },
    },
  ];
});

/** Aliases and global shortcuts the person gave to commands (Settings › Search). */
export const personal = perLang((lang): Record<string, { alias?: string; hotkey?: readonly string[] }> => ({
  "tool.clipboard": { alias: "cl", hotkey: ["⌃", "⌥", "V"] },
  "tool.emoji": { alias: "em", hotkey: ["⌃", "⌥", "E"] },
  "tool.colorPicker": { alias: pick(lang)("cor", "cp") },
  "window.leftHalf": { hotkey: ["⌃", "⌥", "←"] },
  "window.rightHalf": { hotkey: ["⌃", "⌥", "→"] },
  "window.maximize": { hotkey: ["⌃", "⌥", "↩"] },
  "system.darkMode": { alias: "dk" },
}));
