/**
 * The converter's catalog and arithmetic, as CleenKit has them: nine categories, their
 * units in the picker's order, Foundation's factors, and numbers written in the page's
 * locale (pt: comma for decimals, dot for thousands; en: the other way round). Reading
 * accepts both, like ConverterNumber.parse.
 */

import { locale, type Lang } from "@/lib/lang";

export type CategoryId = "length" | "mass" | "temperature" | "volume" | "speed" | "area" | "data" | "time" | "currency";

export type Unit = {
  id: string;
  name: string;
  /** Short form for the "1 km = 0,6214 mi" line. */
  symbol: string;
  /** How many base units one of this is (metres, kilos, litres…); not for °C/°F/K or money. */
  factor?: number;
};

export type Category = { id: CategoryId; title: string; units: Unit[]; pair: { from: string; to: string } };

/** A name as the app localizes it: one string when both languages read the same, else [pt, en]. */
type Text = string | readonly [pt: string, en: string];

type UnitSource = { id: string; name: Text; symbol: Text; factor?: number };
type CategorySource = { id: CategoryId; title: Text; units: UnitSource[]; pair: Record<Lang, { from: string; to: string }> | { from: string; to: string } };

const u = (id: string, name: Text, symbol: Text, factor?: number): UnitSource => ({ id, name, symbol, factor });

function text(value: Text, lang: Lang): string {
  return typeof value === "string" ? value : value[lang === "en" ? 1 : 0];
}

/**
 * One day's reference rates, as Frankfurter publishes them from the ECB: how many of
 * each currency one US dollar buys. Fixed for the site; the app downloads them.
 */
const rates: Record<string, number> = {
  USD: 1,
  BRL: 5.412,
  EUR: 0.8613,
  GBP: 0.7486,
  JPY: 151.84,
  CAD: 1.4018,
  AUD: 1.5362,
  CHF: 0.7974,
  CNY: 7.1214,
  MXN: 18.362,
};

const sources: CategorySource[] = [
  {
    id: "length",
    title: ["Comprimento", "Length"],
    pair: { from: "km", to: "mi" },
    units: [
      u("mm", ["Milímetros", "Millimeters"], "mm", 0.001),
      u("cm", ["Centímetros", "Centimeters"], "cm", 0.01),
      u("m", ["Metros", "Meters"], "m", 1),
      u("km", ["Quilômetros", "Kilometers"], "km", 1000),
      u("in", ["Polegadas", "Inches"], "pol", 0.0254),
      u("ft", ["Pés", "Feet"], ["pés", "ft"], 0.3048),
      u("yd", ["Jardas", "Yards"], "jd", 0.9144),
      u("mi", ["Milhas", "Miles"], "mi", 1609.344),
      u("nmi", ["Milhas náuticas", "Nautical miles"], "mn", 1852),
    ],
  },
  {
    id: "mass",
    title: ["Massa", "Mass"],
    pair: { from: "kg", to: "lb" },
    units: [
      u("mg", ["Miligramas", "Milligrams"], "mg", 1e-6),
      u("g", ["Gramas", "Grams"], "g", 0.001),
      u("kg", ["Quilos", "Kilograms"], "kg", 1),
      u("t", ["Toneladas", "Tonnes"], "t", 1000),
      u("oz", ["Onças", "Ounces"], "oz", 0.028349523125),
      u("lb", ["Libras", "Pounds"], "lb", 0.45359237),
      u("st", "Stones", "st", 6.35029318),
    ],
  },
  {
    id: "temperature",
    title: ["Temperatura", "Temperature"],
    pair: { from: "c", to: "f" },
    units: [u("c", "Celsius", "°C"), u("f", "Fahrenheit", "°F"), u("k", "Kelvin", "K")],
  },
  {
    id: "volume",
    title: "Volume",
    pair: { from: "l", to: "gal" },
    units: [
      u("ml", ["Mililitros", "Milliliters"], "ml", 0.001),
      u("l", ["Litros", "Liters"], "l", 1),
      u("m3", ["Metros cúbicos", "Cubic meters"], "m³", 1000),
      u("tsp", ["Colheres de chá", "Teaspoons"], ["c. chá", "tsp"], 0.00492892159375),
      u("tbsp", ["Colheres de sopa", "Tablespoons"], ["c. sopa", "tbsp"], 0.01478676478125),
      u("cup", ["Xícaras", "Cups"], "xíc.", 0.24),
      u("floz", ["Onças líquidas", "Fluid ounces"], "fl oz", 0.0295735295625),
      u("gal", ["Galões (EUA)", "Gallons (US)"], "gal", 3.785411784),
      u("galuk", ["Galões (RU)", "Gallons (UK)"], ["gal RU", "gal UK"], 4.54609),
    ],
  },
  {
    id: "speed",
    title: ["Velocidade", "Speed"],
    pair: { from: "kmh", to: "mph" },
    units: [u("mps", ["Metros por segundo", "Meters per second"], "m/s", 1), u("kmh", ["Quilômetros por hora", "Kilometers per hour"], "km/h", 1 / 3.6), u("mph", ["Milhas por hora", "Miles per hour"], "mph", 0.44704), u("kn", ["Nós", "Knots"], ["nós", "kn"], 1852 / 3600)],
  },
  {
    id: "area",
    title: ["Área", "Area"],
    pair: { from: "m2", to: "ft2" },
    units: [
      u("cm2", ["Centímetros quadrados", "Square centimeters"], "cm²", 1e-4),
      u("m2", ["Metros quadrados", "Square meters"], "m²", 1),
      u("ha", "Hectares", "ha", 1e4),
      u("km2", ["Quilômetros quadrados", "Square kilometers"], "km²", 1e6),
      u("ft2", ["Pés quadrados", "Square feet"], ["pés²", "ft²"], 0.09290304),
      u("ac", "Acres", "ac", 4046.8564224),
      u("mi2", ["Milhas quadradas", "Square miles"], "mi²", 2589988.110336),
    ],
  },
  {
    id: "data",
    title: ["Dados", "Data"],
    pair: { from: "GB", to: "MB" },
    units: [
      u("bit", "Bits", "bit", 0.125),
      u("B", "Bytes", "B", 1),
      u("KB", "Kilobytes", "KB", 1e3),
      u("MB", "Megabytes", "MB", 1e6),
      u("GB", "Gigabytes", "GB", 1e9),
      u("TB", "Terabytes", "TB", 1e12),
      u("PB", "Petabytes", "PB", 1e15),
      u("MiB", "Mebibytes", "MiB", 1048576),
      u("GiB", "Gibibytes", "GiB", 1073741824),
    ],
  },
  {
    id: "time",
    title: ["Duração", "Duration"],
    pair: { from: "h", to: "min" },
    units: [
      u("ms", ["Milissegundos", "Milliseconds"], "ms", 0.001),
      u("s", ["Segundos", "Seconds"], "s", 1),
      u("min", ["Minutos", "Minutes"], "min", 60),
      u("h", ["Horas", "Hours"], "h", 3600),
      u("d", ["Dias", "Days"], "d", 86400),
      u("wk", ["Semanas", "Weeks"], "sem", 604800),
      // The Gregorian average year, 365,2425 days, like the app.
      u("yr", ["Anos", "Years"], "anos", 31556952),
    ],
  },
  {
    id: "currency",
    title: ["Moeda", "Currency"],
    // The app opens on BRL → USD; an English visitor more likely converts dollars.
    pair: { pt: { from: "BRL", to: "USD" }, en: { from: "USD", to: "EUR" } },
    units: [
      u("BRL", ["Real brasileiro", "Brazilian Real"], "BRL"),
      u("USD", ["Dólar americano", "US Dollar"], "USD"),
      u("EUR", "Euro", "EUR"),
      u("GBP", ["Libra esterlina", "British Pound"], "GBP"),
      u("JPY", ["Iene japonês", "Japanese Yen"], "JPY"),
      u("CAD", ["Dólar canadense", "Canadian Dollar"], "CAD"),
      u("AUD", ["Dólar australiano", "Australian Dollar"], "AUD"),
      u("CHF", ["Franco suíço", "Swiss Franc"], "CHF"),
      u("CNY", ["Yuan chinês", "Chinese Yuan"], "CNY"),
      u("MXN", ["Peso mexicano", "Mexican Peso"], "MXN"),
    ],
  },
];

function build(lang: Lang): Category[] {
  return sources.map(({ id, title, units, pair }) => ({
    id,
    title: text(title, lang),
    pair: "from" in pair ? pair : pair[lang],
    units: units.map((unit) => ({ id: unit.id, name: text(unit.name, lang), symbol: text(unit.symbol, lang), factor: unit.factor })),
  }));
}

const built: Record<Lang, Category[]> = { pt: build("pt"), en: build("en") };

/** The nine categories with their names in `lang`. */
export function categoriesFor(lang: Lang): Category[] {
  return built[lang];
}

/** The Portuguese catalog, as before the English page. */
export const categories: Category[] = built.pt;

export function category(id: CategoryId, lang: Lang = "pt"): Category {
  const list = built[lang];
  return list.find((entry) => entry.id === id) ?? list[0]!;
}

function toCelsius(value: number, id: string): number {
  if (id === "f") return ((value - 32) * 5) / 9;
  if (id === "k") return value - 273.15;
  return value;
}

function fromCelsius(value: number, id: string): number {
  if (id === "f") return (value * 9) / 5 + 32;
  if (id === "k") return value + 273.15;
  return value;
}

/** Converts between two units of one category (UnitConversion.convert). */
export function convert(value: number, from: Unit, to: Unit, kind: CategoryId): number | null {
  if (from.id === to.id) return value;
  if (kind === "temperature") return fromCelsius(toCelsius(value, from.id), to.id);
  if (kind === "currency") {
    const source = rates[from.id];
    const target = rates[to.id];
    return source && target ? (value / source) * target : null;
  }
  return from.factor && to.factor ? (value * from.factor) / to.factor : null;
}

/**
 * Reads "1.234,56", "1234,56", "0,5", "-3" and the dot-decimal "1.5" people type out
 * of habit (ConverterNumber.parse). With both marks the last is the decimal; a lone
 * comma is decimal; dots alone are thousands only when every group has three digits.
 */
export function parseNumber(text: string): number | null {
  let raw = text.trim().replace(/[\s ]/g, "").replace("−", "-");
  if (!raw) return null;
  let sign = 1;
  if (raw.startsWith("-")) {
    sign = -1;
    raw = raw.slice(1);
  } else if (raw.startsWith("+")) {
    raw = raw.slice(1);
  }
  if (!raw || !/^[0-9.,]+$/.test(raw)) return null;
  const comma = raw.lastIndexOf(",");
  const dot = raw.lastIndexOf(".");
  let normalized: string;
  if (comma >= 0 && dot >= 0) {
    const decimal = comma > dot ? "," : ".";
    const grouping = decimal === "," ? "." : ",";
    const parts = raw.split(decimal);
    if (parts.length !== 2) return null;
    normalized = `${parts[0]!.split(grouping).join("")}.${parts[1]}`;
  } else if (comma >= 0) {
    const parts = raw.split(",");
    if (parts.length !== 2) return null;
    normalized = `${parts[0]}.${parts[1]}`;
  } else if (dot >= 0) {
    const parts = raw.split(".");
    const grouping = parts.length > 1 && parts[0] !== "" && parts.slice(1).every((part) => part.length === 3);
    if (grouping) normalized = parts.join("");
    else if (parts.length === 2) normalized = `${parts[0]}.${parts[1]}`;
    else return null;
  } else {
    normalized = raw;
  }
  if (normalized === ".") return null;
  const value = Number(normalized.startsWith(".") ? `0${normalized}` : normalized);
  return Number.isFinite(value) ? sign * value : null;
}

/**
 * A result as people read it: "1,6093", "12.345,7", "0,0006214" (ConverterNumber.format),
 * or "1.6093", "12,345.7" in English. Around six significant digits, never trailing zeros;
 * money always shows cents.
 */
export function formatNumber(value: number, isCurrency = false, lang: Lang = "pt"): string {
  const tag = locale[lang];
  if (!Number.isFinite(value)) return "—";
  if (value === 0) return "0";
  const magnitude = Math.abs(value);
  if (magnitude >= 1e15 || magnitude < 1e-9) return new Intl.NumberFormat(tag, { notation: "scientific", maximumSignificantDigits: 4 }).format(value);
  if (isCurrency && magnitude >= 0.01) return new Intl.NumberFormat(tag, { minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(value);
  if (magnitude >= 1) {
    const integerDigits = Math.floor(Math.log10(magnitude)) + 1;
    return new Intl.NumberFormat(tag, { maximumFractionDigits: Math.max(0, Math.min(4, 6 - integerDigits)) }).format(value);
  }
  return new Intl.NumberFormat(tag, { maximumSignificantDigits: 4 }).format(value);
}
