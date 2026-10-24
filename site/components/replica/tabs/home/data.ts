/** Made-up content for Início: three tracks, a week of events and a few reminders. */

export type Track = { title: string; album: string; artist: string; artwork: string };

/** Artwork as layered gradients, so each cover reads as a real one at 88 pt. */
export const tracks: Track[] = [
  {
    title: "Maré Alta",
    album: "Litoral",
    artist: "Banda Sal",
    artwork:
      "radial-gradient(circle at 70% 30%, rgba(255,236,179,0.95) 0 12%, transparent 13%), linear-gradient(180deg, #ff8a5b 0%, #f2546b 46%, #3b2a6b 47%, #1d3b74 70%, #0f2547 100%)",
  },
  {
    title: "Céu de Setembro",
    album: "Horizonte",
    artist: "Vento Norte",
    artwork:
      "radial-gradient(circle at 72% 30%, rgba(248,255,174,0.9) 0 9%, rgba(248,255,174,0.25) 10%, transparent 34%), radial-gradient(ellipse 90% 45% at 20% 100%, #0b2f3a 0 60%, transparent 61%), radial-gradient(ellipse 80% 40% at 85% 105%, #134e5e 0 60%, transparent 61%), linear-gradient(180deg, #2b5876 0%, #4e9a9a 55%, #9fd8c8 100%)",
  },
  {
    title: "Luz da Tarde",
    album: "Estações",
    artist: "Coral Maresia",
    artwork:
      "radial-gradient(circle at 50% 120%, #ffd36e 0 30%, transparent 31%), linear-gradient(160deg, #2b1055 0%, #7597de 100%)",
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
