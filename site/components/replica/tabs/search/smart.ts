/**
 * The calculator's smarter half: money, units, time zones and dates typed in plain
 * Portuguese ("100 usd em brl", "5 km em mi", "15h em Tóquio", "hoje + 45 dias").
 * Rates and offsets are fixed here; the app reads the day's rates and the real zones.
 */

/** A conversion's answer: the figure to copy and the line under it. */
export type Smart = { title: string; subtitle: string; copy: string };

const number = (digits: number) => new Intl.NumberFormat("pt-BR", { maximumFractionDigits: digits, minimumFractionDigits: 0 });
const money = new Intl.NumberFormat("pt-BR", { minimumFractionDigits: 2, maximumFractionDigits: 2 });

/** "1.250,50", "1250,5", "1.5" (ConverterNumber.parse's rules, shortened). */
function parseAmount(raw: string): number | null {
  const negative = raw.startsWith("-");
  const digits = negative ? raw.slice(1) : raw;
  let text: string;
  if (digits.includes(",")) text = digits.replaceAll(".", "").replace(",", ".");
  else if (/^\d{1,3}(\.\d{3})+$/.test(digits)) text = digits.replaceAll(".", "");
  else text = digits;
  const value = Number(text);
  return Number.isFinite(value) && text.length > 0 ? (negative ? -value : value) : null;
}

// MARK: Money

/** Units of each currency one dollar buys: a typical day, for the demo. */
const perDollar: Record<string, number> = { USD: 1, BRL: 5.37, EUR: 0.861, GBP: 0.747, JPY: 151.2, ARS: 1385, CAD: 1.39 };

const currencyNames: Record<string, string> = {
  usd: "USD", dolar: "USD", dolares: "USD", "us$": "USD",
  brl: "BRL", real: "BRL", reais: "BRL", "r$": "BRL",
  eur: "EUR", euro: "EUR", euros: "EUR",
  gbp: "GBP", libra: "GBP", libras: "GBP",
  jpy: "JPY", iene: "JPY", ienes: "JPY",
  ars: "ARS", peso: "ARS", pesos: "ARS",
  cad: "CAD",
};

const symbols: Record<string, string> = { BRL: "R$", USD: "US$", EUR: "€", GBP: "£", JPY: "¥", ARS: "ARS", CAD: "CA$" };

// MARK: Units

type Unit = { factor: number; symbol: string; dimension: "length" | "mass" | "volume" | "temperature" | "data" | "speed" };

const units: Record<string, Unit> = {
  mm: { factor: 0.001, symbol: "mm", dimension: "length" },
  cm: { factor: 0.01, symbol: "cm", dimension: "length" },
  m: { factor: 1, symbol: "m", dimension: "length" },
  km: { factor: 1000, symbol: "km", dimension: "length" },
  pol: { factor: 0.0254, symbol: "pol", dimension: "length" },
  in: { factor: 0.0254, symbol: "pol", dimension: "length" },
  ft: { factor: 0.3048, symbol: "pés", dimension: "length" },
  pes: { factor: 0.3048, symbol: "pés", dimension: "length" },
  mi: { factor: 1609.344, symbol: "mi", dimension: "length" },
  milhas: { factor: 1609.344, symbol: "mi", dimension: "length" },
  g: { factor: 1, symbol: "g", dimension: "mass" },
  kg: { factor: 1000, symbol: "kg", dimension: "mass" },
  lb: { factor: 453.592, symbol: "lb", dimension: "mass" },
  oz: { factor: 28.3495, symbol: "oz", dimension: "mass" },
  ml: { factor: 0.001, symbol: "ml", dimension: "volume" },
  l: { factor: 1, symbol: "l", dimension: "volume" },
  gal: { factor: 3.78541, symbol: "gal", dimension: "volume" },
  mb: { factor: 1e6, symbol: "MB", dimension: "data" },
  gb: { factor: 1e9, symbol: "GB", dimension: "data" },
  tb: { factor: 1e12, symbol: "TB", dimension: "data" },
  kmh: { factor: 1, symbol: "km/h", dimension: "speed" },
  mph: { factor: 1.609344, symbol: "mph", dimension: "speed" },
  c: { factor: 1, symbol: "°C", dimension: "temperature" },
  f: { factor: 1, symbol: "°F", dimension: "temperature" },
  k: { factor: 1, symbol: "K", dimension: "temperature" },
};

function toCelsius(value: number, unit: string) {
  if (unit === "f") return ((value - 32) * 5) / 9;
  if (unit === "k") return value - 273.15;
  return value;
}

function fromCelsius(value: number, unit: string) {
  if (unit === "f") return (value * 9) / 5 + 32;
  if (unit === "k") return value + 273.15;
  return value;
}

/** "1,6093", "12.345,7": about six significant digits, no trailing zeros. */
function figure(value: number) {
  const magnitude = Math.abs(value);
  if (magnitude >= 1) return number(Math.max(0, Math.min(4, 6 - (Math.floor(Math.log10(magnitude)) + 1)))).format(value);
  return new Intl.NumberFormat("pt-BR", { maximumSignificantDigits: 4 }).format(value);
}

const pair = /^(-?[\d.,]+)\s*([\p{L}$°/]+)\s+(?:em|para|in|to|→)\s+([\p{L}$°/]+)$/iu;

function fold(text: string) {
  return text.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase().replace("°", "").replace("/", "");
}

function convert(text: string): Smart | null {
  const match = pair.exec(text.trim());
  if (!match) return null;
  const amount = parseAmount(match[1]!);
  if (amount === null) return null;
  const from = fold(match[2]!);
  const to = fold(match[3]!);

  const source = currencyNames[from];
  const target = currencyNames[to];
  if (source && target) {
    const value = (amount / perDollar[source]!) * perDollar[target]!;
    const shown = `${symbols[target]} ${money.format(value)}`;
    return { title: shown, subtitle: `${symbols[source]} ${money.format(amount)} · cotação de hoje`, copy: money.format(value) };
  }

  const a = units[from];
  const b = units[to];
  if (!a || !b || a.dimension !== b.dimension) return null;
  const value = a.dimension === "temperature" ? fromCelsius(toCelsius(amount, from), to) : (amount * a.factor) / b.factor;
  return { title: `${figure(value)} ${b.symbol}`, subtitle: `${figure(amount)} ${a.symbol}`, copy: figure(value) };
}

// MARK: Time zones

/** Hours from São Paulo (UTC−3), at this time of year. */
const zones: Record<string, { name: string; offset: number }> = {
  toquio: { name: "Tóquio", offset: 12 },
  tokyo: { name: "Tóquio", offset: 12 },
  londres: { name: "Londres", offset: 3 },
  london: { name: "Londres", offset: 3 },
  lisboa: { name: "Lisboa", offset: 3 },
  paris: { name: "Paris", offset: 4 },
  berlim: { name: "Berlim", offset: 4 },
  "nova york": { name: "Nova York", offset: -1 },
  ny: { name: "Nova York", offset: -1 },
  "sao francisco": { name: "São Francisco", offset: -4 },
  sf: { name: "São Francisco", offset: -4 },
  sydney: { name: "Sydney", offset: 14 },
};

const clock = /^(\d{1,2})(?:h|:)(\d{2})?\s*(?:em|in|para)\s+(.+)$/i;

function zone(text: string): Smart | null {
  const match = clock.exec(text.trim());
  if (!match) return null;
  const hour = Number(match[1]);
  const minute = Number(match[2] ?? 0);
  const place = zones[fold(match[3]!).trim()];
  if (!place || hour > 23 || minute > 59) return null;
  const total = hour + place.offset;
  const shifted = ((total % 24) + 24) % 24;
  const day = total >= 24 ? " · amanhã lá" : total < 0 ? " · ontem lá" : "";
  const time = (h: number) => `${String(h).padStart(2, "0")}:${String(minute).padStart(2, "0")}`;
  return { title: `${time(shifted)} em ${place.name}`, subtitle: `${time(hour)} aqui${day}`, copy: time(shifted) };
}

// MARK: Dates

const span = /^(hoje|amanha)\s*([+-])\s*(\d+)\s*(dias?|semanas?|mes|meses)$/i;

function date(text: string): Smart | null {
  const match = span.exec(fold(text.trim()));
  if (!match) return null;
  const base = new Date();
  if (match[1] === "amanha") base.setDate(base.getDate() + 1);
  const amount = Number(match[3]) * (match[2] === "-" ? -1 : 1);
  const unit = match[4]!;
  if (unit.startsWith("dia")) base.setDate(base.getDate() + amount);
  else if (unit.startsWith("semana")) base.setDate(base.getDate() + amount * 7);
  else base.setMonth(base.getMonth() + amount);
  const long = new Intl.DateTimeFormat("pt-BR", { weekday: "long", day: "numeric", month: "long", year: "numeric" }).format(base);
  const short = new Intl.DateTimeFormat("pt-BR").format(base);
  return { title: long.charAt(0).toUpperCase() + long.slice(1), subtitle: text.trim(), copy: short };
}

/** Whatever the text asks for, or nil when it isn't one of these. */
export function smart(text: string): { section: string; result: Smart } | null {
  const conversion = convert(text);
  if (conversion) return { section: "Calculadora", result: conversion };
  const time = zone(text);
  if (time) return { section: "Calculadora", result: time };
  const day = date(text);
  if (day) return { section: "Calculadora", result: day };
  return null;
}
