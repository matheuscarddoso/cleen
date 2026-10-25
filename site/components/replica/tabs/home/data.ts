/** Content for Início: Drake's newest songs, and a made-up week of events and a few reminders. */

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
export const monthLabel = "Out";
export const firstDay = 12;
export const lastDay = 31;

const narrow = ["D", "S", "T", "Q", "Q", "S", "S"] as const;
const short = ["DOM", "SEG", "TER", "QUA", "QUI", "SEX", "SÁB"] as const;
const long = ["domingo", "segunda-feira", "terça-feira", "quarta-feira", "quinta-feira", "sexta-feira", "sábado"] as const;

/** 1 October 2026 is a Thursday. */
const weekday = (day: number) => (day + 3) % 7;

export const dayLetter = (day: number) => narrow[weekday(day)] ?? "";
export const dayShort = (day: number) => short[weekday(day)] ?? "";
export const dayName = (day: number) => `${long[weekday(day)] ?? ""}, ${day} de outubro`;
export const isWeekend = (day: number) => weekday(day) === 0 || weekday(day) === 6;

export type CalendarEvent = { title: string; time: string; color: string };

/** Calendar colors as macOS draws them in dark mode. */
const blue = "rgb(10,132,255)";
const green = "rgb(48,209,88)";
const orange = "rgb(255,159,10)";
const purple = "rgb(191,90,242)";
const red = "rgb(255,69,58)";

export const events: Record<number, CalendarEvent[]> = {
  14: [{ title: "Aula de inglês", time: "19:00 – 20:00", color: purple }],
  16: [{ title: "Corrida no parque", time: "07:00 – 08:00", color: green }],
  20: [{ title: "Aula de inglês", time: "19:00 – 20:00", color: purple }],
  22: [{ title: "Reunião de produto", time: "15:00 – 15:45", color: blue }],
  23: [
    { title: "Dentista", time: "09:30 – 10:30", color: green },
    { title: "Happy hour do time", time: "18:00 – 20:00", color: orange },
  ],
  24: [{ title: "Feira na praça", time: "Dia todo", color: orange }],
  27: [{ title: "Entrega do relatório", time: "Dia todo", color: red }],
  29: [{ title: "Revisão trimestral", time: "10:00 – 11:30", color: blue }],
};

export type Reminder = { id: string; title: string };

export const reminders: Reminder[] = [
  { id: "proposta", title: "Enviar a proposta revisada" },
  { id: "cafe", title: "Comprar café" },
  { id: "seguro", title: "Renovar o seguro" },
  { id: "revisao", title: "Levar o carro na revisão" },
];
