/** Content for Início: three Drake songs, and a made-up week of events and a few reminders. */

export type Track = { title: string; album: string; artist: string; artwork: string };

/** Artwork as layered gradients in each album's mood, so every cover reads as one at 88 pt. */
export const tracks: Track[] = [
  {
    title: "Hotline Bling",
    album: "Views",
    artist: "Drake",
    artwork:
      "radial-gradient(circle at 30% 28%, rgba(255,214,240,0.85) 0 9%, rgba(255,120,200,0.25) 10%, transparent 32%), linear-gradient(160deg, #ff4fa3 0%, #a23cf0 52%, #2a1a6e 100%)",
  },
  {
    title: "Passionfruit",
    album: "More Life",
    artist: "Drake",
    artwork:
      "radial-gradient(circle at 50% 58%, #ffe08a 0 17%, rgba(255,200,110,0.35) 18%, transparent 36%), linear-gradient(180deg, #ffab45 0%, #e8573a 58%, #7a2335 100%)",
  },
  {
    title: "God's Plan",
    album: "Scorpion",
    artist: "Drake",
    artwork:
      "radial-gradient(ellipse 120% 38% at 50% 100%, #141414 0 60%, transparent 61%), linear-gradient(180deg, #f1f1f1 0%, #a9a9a9 55%, #3a3a3a 100%)",
  },
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
