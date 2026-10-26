/** Content for Início: Drake's newest songs, and a made-up week of events and a few reminders. */

import { pick, type Lang } from "@/lib/lang";

export type Track = { title: string; album: string; artist: string; artwork: string };

/** The album covers, as a CSS background. */
const cover = (file: string) => `#000 url(/covers/${file}) center / cover no-repeat`;

export const tracks: Track[] = [
  { title: "Janice STFU", album: "ICEMAN", artist: "Drake", artwork: cover("iceman.jpg") },
  { title: "Hoe Phase", album: "MAID OF HONOUR", artist: "Drake", artwork: cover("maid-of-honour.jpg") },
  { title: "Burning Bridges", album: "ICEMAN", artist: "Drake", artwork: cover("iceman.jpg") },
  { title: "Dust", album: "ICEMAN", artist: "Drake", artwork: cover("iceman.jpg") },
];

/** Today in the replica: quinta-feira, 22 de outubro (the menu bar's "qui"). */
export const today = 22;
export const firstDay = 12;
export const lastDay = 31;

const narrow = ["D", "S", "T", "Q", "Q", "S", "S"] as const;
const short = ["DOM", "SEG", "TER", "QUA", "QUI", "SEX", "SÁB"] as const;
const long = ["domingo", "segunda-feira", "terça-feira", "quarta-feira", "quinta-feira", "sexta-feira", "sábado"] as const;

/** 1 October 2026 is a Thursday. */
const weekday = (day: number) => (day + 3) % 7;

/**
 * English goes through Intl (en-US names are the same in every engine); Portuguese keeps
 * its tables, written as the app shows them, so server and browser never disagree.
 */
const october = (day: number) => new Date(2026, 9, day, 12);
const english = (day: number, options: Intl.DateTimeFormatOptions) => new Intl.DateTimeFormat("en-US", options).format(october(day));

export const monthLabel = (lang: Lang = "pt") => (lang === "en" ? english(today, { month: "short" }).replace(".", "") : "Out");
export const dayLetter = (day: number, lang: Lang = "pt") => (lang === "en" ? english(day, { weekday: "narrow" }) : (narrow[weekday(day)] ?? ""));
export const dayShort = (day: number, lang: Lang = "pt") => (lang === "en" ? english(day, { weekday: "short" }).replace(".", "").toUpperCase() : (short[weekday(day)] ?? ""));
export const dayName = (day: number, lang: Lang = "pt") =>
  lang === "en" ? english(day, { weekday: "long", month: "long", day: "numeric" }) : `${long[weekday(day)] ?? ""}, ${day} de outubro`;
export const isWeekend = (day: number) => weekday(day) === 0 || weekday(day) === 6;

/** The greeting's date line: "Quinta-feira, 22 de outubro", "Thursday, October 22". */
export const todayLabel = (lang: Lang = "pt") => {
  const name = dayName(today, lang);
  return name.charAt(0).toUpperCase() + name.slice(1);
};

export type CalendarEvent = { title: string; time: string; color: string };

/** Calendar colors as macOS draws them in dark mode. */
const blue = "rgb(10,132,255)";
const green = "rgb(48,209,88)";
const orange = "rgb(255,159,10)";
const purple = "rgb(191,90,242)";
const red = "rgb(255,69,58)";

/** "19:00 – 20:00" as AgendaEvent writes it: each end in the locale's clock, joined by a dash. */
function span(start: string, end: string, lang: Lang): string {
  if (lang === "pt") return `${start} – ${end}`;
  // Newer ICU puts a narrow no-break space before AM/PM; a plain one keeps server and browser equal.
  const clock = (time: string) => {
    const [hour = 0, minute = 0] = time.split(":").map(Number);
    return new Intl.DateTimeFormat("en-US", { hour: "numeric", minute: "2-digit" }).format(new Date(2026, 9, 1, hour, minute)).replace(/\s/g, " ");
  };
  return `${clock(start)} – ${clock(end)}`;
}

export function events(lang: Lang = "pt"): Record<number, CalendarEvent[]> {
  const l = pick(lang);
  const allDay = l("Dia todo", "All day");
  return {
    14: [{ title: l("Aula de inglês", "Spanish class"), time: span("19:00", "20:00", lang), color: purple }],
    16: [{ title: l("Corrida no parque", "Run in the park"), time: span("07:00", "08:00", lang), color: green }],
    20: [{ title: l("Aula de inglês", "Spanish class"), time: span("19:00", "20:00", lang), color: purple }],
    22: [{ title: l("Reunião de produto", "Product meeting"), time: span("15:00", "15:45", lang), color: blue }],
    23: [
      { title: l("Dentista", "Dentist"), time: span("09:30", "10:30", lang), color: green },
      { title: l("Happy hour do time", "Team happy hour"), time: span("18:00", "20:00", lang), color: orange },
    ],
    24: [{ title: l("Feira na praça", "Farmers market"), time: allDay, color: orange }],
    27: [{ title: l("Entrega do relatório", "Report due"), time: allDay, color: red }],
    29: [{ title: l("Revisão trimestral", "Quarterly review"), time: span("10:00", "11:30", lang), color: blue }],
  };
}

export type Reminder = { id: string; title: string };

export function reminders(lang: Lang = "pt"): Reminder[] {
  const l = pick(lang);
  return [
    { id: "proposta", title: l("Enviar a proposta revisada", "Send the revised proposal") },
    { id: "cafe", title: l("Comprar café", "Buy coffee") },
    { id: "seguro", title: l("Renovar o seguro", "Renew insurance") },
    { id: "revisao", title: l("Levar o carro na revisão", "Take the car in for service") },
  ];
}
