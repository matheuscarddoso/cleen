/**
 * The calculator's smarter half: money, units, time zones and dates typed in plain
 * words ("100 usd em brl", "5 km to mi", "15h em Tóquio", "3pm in Tokyo",
 * "today + 45 days"). Rates and offsets are fixed here; the app reads the day's rates
 * and the real zones. Portuguese reads the way it always did; English also takes the
 * forms the app's UnitQuery, TimeZoneQuery and DateQuery accept.
 */

import { locale, pick, type Lang } from "@/lib/lang";

/** A conversion's answer: the figure to copy and the line under it. */
export type Smart = { title: string; subtitle: string; copy: string };

const number = (lang: Lang, digits: number) => new Intl.NumberFormat(locale[lang], { maximumFractionDigits: digits, minimumFractionDigits: 0 });
const money = { pt: new Intl.NumberFormat("pt-BR", { minimumFractionDigits: 2, maximumFractionDigits: 2 }), en: new Intl.NumberFormat("en-US", { minimumFractionDigits: 2, maximumFractionDigits: 2 }) };

/** "1.250,50", "1250,5", "1.5" (ConverterNumber.parse's rules, shortened). */
function parseAmount(raw: string, lang: Lang): number | null {
  const negative = raw.startsWith("-");
  const digits = negative ? raw.slice(1) : raw;
  let text: string;
  if (lang === "en") {
    // "1,250.50", "1,250", "1.5"; a lone comma with no thousands after it is a decimal.
    if (digits.includes(",") && (digits.includes(".") || /^\d{1,3}(,\d{3})+$/.test(digits))) text = digits.replaceAll(",", "");
    else text = digits.replace(",", ".");
  } else if (digits.includes(",")) text = digits.replaceAll(".", "").replace(",", ".");
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

/** English names on top (UnitQuery.currencyAliases). "pound" is the weight, as there. */
const currencyNamesEnglish: Record<string, string> = {
  ...currencyNames,
  libra: "", libras: "", peso: "", pesos: "",
  dollar: "USD", dollars: "USD", $: "USD",
  "€": "EUR",
  "£": "GBP",
  yen: "JPY", "¥": "JPY",
};

const symbols: Record<Lang, Record<string, string>> = {
  pt: { BRL: "R$", USD: "US$", EUR: "€", GBP: "£", JPY: "¥", ARS: "ARS", CAD: "CA$" },
  en: { BRL: "R$", USD: "$", EUR: "€", GBP: "£", JPY: "¥", ARS: "ARS", CAD: "CA$" },
};

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

/** The same units under their English names and symbols (UnitQuery.unitAliases). */
const unitsEnglish: Record<string, Unit> = (() => {
  const table: Record<string, Unit> = { ...units, in: { ...units.in!, symbol: "in" }, ft: { ...units.ft!, symbol: "ft" } };
  delete table.pol;
  delete table.pes;
  delete table.milhas;
  const add = (id: string, words: string[]) => words.forEach((word) => (table[word] = table[id]!));
  add("mm", ["millimeter", "millimeters"]);
  add("cm", ["centimeter", "centimeters"]);
  add("m", ["meter", "meters", "metre", "metres"]);
  add("km", ["kms", "kilometer", "kilometers"]);
  add("in", ["inch", "inches"]);
  add("ft", ["foot", "feet"]);
  add("mi", ["mile", "miles"]);
  add("g", ["gram", "grams"]);
  add("kg", ["kgs", "kilo", "kilos", "kilogram", "kilograms"]);
  add("lb", ["lbs", "pound", "pounds"]);
  add("oz", ["ounce", "ounces"]);
  add("ml", ["milliliter", "milliliters"]);
  add("l", ["liter", "liters", "litre", "litres"]);
  add("gal", ["gallon", "gallons"]);
  add("mb", ["megabyte", "megabytes"]);
  add("gb", ["gigabyte", "gigabytes"]);
  add("tb", ["terabyte", "terabytes"]);
  add("kmh", ["kph"]);
  add("c", ["celsius"]);
  add("f", ["fahrenheit"]);
  add("k", ["kelvin"]);
  return table;
})();

function toCelsius(value: number, unit: string) {
  if (unit === "f" || unit === "fahrenheit") return ((value - 32) * 5) / 9;
  if (unit === "k" || unit === "kelvin") return value - 273.15;
  return value;
}

function fromCelsius(value: number, unit: string) {
  if (unit === "f" || unit === "fahrenheit") return (value * 9) / 5 + 32;
  if (unit === "k" || unit === "kelvin") return value + 273.15;
  return value;
}

/** "1,6093", "12.345,7": about six significant digits, no trailing zeros. */
function figure(value: number, lang: Lang) {
  const magnitude = Math.abs(value);
  if (magnitude >= 1) return number(lang, Math.max(0, Math.min(4, 6 - (Math.floor(Math.log10(magnitude)) + 1)))).format(value);
  return new Intl.NumberFormat(locale[lang], { maximumSignificantDigits: 4 }).format(value);
}

const pair = /^(-?[\d.,]+)\s*([\p{L}$°/]+)\s+(?:em|para|in|to|→)\s+([\p{L}$°/]+)$/iu;
/** English also takes a sign before the number ("$100 to eur") and "as"/"->"/"=". */
const pairEnglish = /^([$€£¥]|r\$|us\$)?\s*(-?[\d.,]+)\s*([\p{L}$€£¥°/]*)\s+(?:em|para|pra|in|to|as|->|→|=)\s+([\p{L}$€£¥°/]+)$/iu;

function fold(text: string) {
  return text.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase().replace("°", "").replace("/", "");
}

function convert(text: string, lang: Lang): Smart | null {
  let amountText: string, fromText: string, toText: string;
  if (lang === "en") {
    const match = pairEnglish.exec(text.trim());
    if (!match) return null;
    const unit = match[1] ?? match[3] ?? "";
    if (unit.length === 0 || (match[1] && match[3])) return null;
    [amountText, fromText, toText] = [match[2]!, unit, match[4]!];
  } else {
    const match = pair.exec(text.trim());
    if (!match) return null;
    [amountText, fromText, toText] = [match[1]!, match[2]!, match[3]!];
  }
  const amount = parseAmount(amountText, lang);
  if (amount === null) return null;
  const from = fold(fromText);
  const to = fold(toText);

  const names = lang === "en" ? currencyNamesEnglish : currencyNames;
  const source = names[from];
  const target = names[to];
  if (source && target) {
    const value = (amount / perDollar[source]!) * perDollar[target]!;
    const format = money[lang];
    const sign = symbols[lang];
    if (lang === "en") {
      // "€86.10", "R$537.00": the sign against the figure, the way US English writes it.
      const shown = (code: string, figure: number) => `${sign[code]}${/^[A-Z]/.test(sign[code]!) ? " " : ""}${format.format(figure)}`;
      return { title: shown(target, value), subtitle: `${shown(source, amount)} · today’s rate`, copy: format.format(value) };
    }
    const shown = `${sign[target]} ${format.format(value)}`;
    return { title: shown, subtitle: `${sign[source]} ${format.format(amount)} · cotação de hoje`, copy: format.format(value) };
  }

  const table = lang === "en" ? unitsEnglish : units;
  const a = table[from];
  const b = table[to];
  if (!a || !b || a.dimension !== b.dimension) return null;
  const value = a.dimension === "temperature" ? fromCelsius(toCelsius(amount, from), to) : (amount * a.factor) / b.factor;
  return { title: `${figure(value, lang)} ${b.symbol}`, subtitle: `${figure(amount, lang)} ${a.symbol}`, copy: figure(value, lang) };
}

// MARK: Time zones

/**
 * Each place's UTC offset at this time of year, and its name in each language. "Here"
 * is São Paulo (UTC−3) in Portuguese and New York (UTC−4) in English.
 */
const here: Record<Lang, number> = { pt: -3, en: -4 };

const places = {
  tokyo: { pt: "Tóquio", en: "Tokyo", utc: 9 },
  london: { pt: "Londres", en: "London", utc: 0 },
  lisbon: { pt: "Lisboa", en: "Lisbon", utc: 0 },
  paris: { pt: "Paris", en: "Paris", utc: 1 },
  berlin: { pt: "Berlim", en: "Berlin", utc: 1 },
  newYork: { pt: "Nova York", en: "New York", utc: -4 },
  sanFrancisco: { pt: "São Francisco", en: "San Francisco", utc: -7 },
  sydney: { pt: "Sydney", en: "Sydney", utc: 11 },
  saoPaulo: { pt: "São Paulo", en: "São Paulo", utc: -3 },
} as const;

type Place = keyof typeof places;

const zones: Record<string, Place> = {
  toquio: "tokyo",
  tokyo: "tokyo",
  londres: "london",
  london: "london",
  lisboa: "lisbon",
  paris: "paris",
  berlim: "berlin",
  "nova york": "newYork",
  ny: "newYork",
  "sao francisco": "sanFrancisco",
  sf: "sanFrancisco",
  sydney: "sydney",
};

/** English names on top, the way TimeZoneQuery.places lists them. */
const zonesEnglish: Record<string, Place> = {
  ...zones,
  japan: "tokyo",
  uk: "london",
  lisbon: "lisbon",
  portugal: "lisbon",
  france: "paris",
  berlin: "berlin",
  germany: "berlin",
  "new york": "newYork",
  nyc: "newYork",
  boston: "newYork",
  miami: "newYork",
  "san francisco": "sanFrancisco",
  "los angeles": "sanFrancisco",
  la: "sanFrancisco",
  seattle: "sanFrancisco",
  australia: "sydney",
  melbourne: "sydney",
  "sao paulo": "saoPaulo",
  brazil: "saoPaulo",
  rio: "saoPaulo",
};

const clock = /^(\d{1,2})(?:h|:)(\d{2})?\s*(?:em|in|para)\s+(.+)$/i;

/** "3pm", "3:30 pm", "9am", "15h", "15h30", "15:30", "15" (TimeZoneQuery.clock). */
function clockEnglish(raw: string): [number, number] | null {
  let text = raw.replaceAll(" ", "");
  if (text.endsWith("am") || text.endsWith("pm")) {
    const offset = text.endsWith("pm") ? 12 : 0;
    text = text.slice(0, -2);
    const time = clockEnglish(text);
    if (!time || time[0] < 1 || time[0] > 12) return null;
    return [(time[0] % 12) + offset, time[1]];
  }
  const match = /^(\d{1,2})(?:[h:](\d{2})?)?$/.exec(text);
  if (!match) return null;
  const hour = Number(match[1]);
  const minute = Number(match[2] ?? 0);
  return hour <= 23 && minute <= 59 ? [hour, minute] : null;
}

function zone(text: string, lang: Lang): Smart | null {
  let hour: number, minute: number, place: Place | undefined;
  if (lang === "en") {
    const match = /^(.+?)\s+(?:in|em)\s+(.+)$/i.exec(fold(text.trim()));
    const time = match ? clockEnglish(match[1]!.trim()) : null;
    if (!match || !time) return null;
    [hour, minute] = time;
    place = zonesEnglish[match[2]!.trim()];
  } else {
    const match = clock.exec(text.trim());
    if (!match) return null;
    hour = Number(match[1]);
    minute = Number(match[2] ?? 0);
    place = zones[fold(match[3]!).trim()];
  }
  if (!place || hour > 23 || minute > 59) return null;
  const { utc, [lang]: name } = places[place];
  const total = hour + utc - here[lang];
  const shifted = ((total % 24) + 24) % 24;
  if (lang === "en") {
    const day = total >= 24 ? " · next day there" : total < 0 ? " · previous day there" : "";
    const time = (h: number) => `${h % 12 === 0 ? 12 : h % 12}:${String(minute).padStart(2, "0")} ${h < 12 ? "AM" : "PM"}`;
    return { title: `${time(shifted)} in ${name}`, subtitle: `${time(hour)} here${day}`, copy: time(shifted) };
  }
  const day = total >= 24 ? " · amanhã lá" : total < 0 ? " · ontem lá" : "";
  const time = (h: number) => `${String(h).padStart(2, "0")}:${String(minute).padStart(2, "0")}`;
  return { title: `${time(shifted)} em ${name}`, subtitle: `${time(hour)} aqui${day}`, copy: time(shifted) };
}

// MARK: Dates

const span = /^(hoje|amanha)\s*([+-])\s*(\d+)\s*(dias?|semanas?|mes|meses)$/i;
const spanEnglish = /^(today|tomorrow|yesterday|hoje|amanha|ontem)\s*([+-])\s*(\d+)\s*(days?|weeks?|months?|years?|dias?|semanas?|mes|meses|anos?)$/i;

/** "in 3 weeks", "10 days ago" read as "today + 3 weeks", "today - 10 days" (DateQuery). */
function spelledOut(text: string): string {
  const ahead = /^in\s+(\d+)\s*(\p{L}+)$/u.exec(text);
  if (ahead) return `today + ${ahead[1]} ${ahead[2]}`;
  const ago = /^(\d+)\s*(\p{L}+)\s+ago$/u.exec(text);
  if (ago) return `today - ${ago[1]} ${ago[2]}`;
  return text;
}

function date(text: string, lang: Lang): Smart | null {
  const folded = fold(text.trim());
  const match = lang === "en" ? spanEnglish.exec(spelledOut(folded)) : span.exec(folded);
  if (!match) return null;
  const base = new Date();
  if (match[1] === "amanha" || match[1] === "tomorrow") base.setDate(base.getDate() + 1);
  if (match[1] === "ontem" || match[1] === "yesterday") base.setDate(base.getDate() - 1);
  const amount = Number(match[3]) * (match[2] === "-" ? -1 : 1);
  const unit = match[4]!;
  if (unit.startsWith("dia") || unit.startsWith("day")) base.setDate(base.getDate() + amount);
  else if (unit.startsWith("semana") || unit.startsWith("week")) base.setDate(base.getDate() + amount * 7);
  else if (unit.startsWith("ano") || unit.startsWith("year")) base.setFullYear(base.getFullYear() + amount);
  else base.setMonth(base.getMonth() + amount);
  const long = new Intl.DateTimeFormat(locale[lang], { weekday: "long", day: "numeric", month: "long", year: "numeric" }).format(base);
  const short = new Intl.DateTimeFormat(locale[lang]).format(base);
  return { title: long.charAt(0).toUpperCase() + long.slice(1), subtitle: text.trim(), copy: short };
}

/** Whatever the text asks for, or nil when it isn't one of these. */
export function smart(text: string, lang: Lang = "pt"): { section: string; result: Smart } | null {
  const section = pick(lang)("Calculadora", "Calculator");
  const conversion = convert(text, lang);
  if (conversion) return { section, result: conversion };
  const time = zone(text, lang);
  if (time) return { section, result: time };
  const day = date(text, lang);
  if (day) return { section, result: day };
  return null;
}
