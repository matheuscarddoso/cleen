/**
 * The converter's catalog and arithmetic, as CleenKit has them: nine categories, their
 * units in the picker's order, Foundation's factors, and numbers read and written the
 * Brazilian way (comma for decimals, dot for thousands).
 */

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

const u = (id: string, name: string, symbol: string, factor?: number): Unit => ({ id, name, symbol, factor });

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

export const categories: Category[] = [
  {
    id: "length",
    title: "Comprimento",
    pair: { from: "km", to: "mi" },
    units: [
      u("mm", "Milímetros", "mm", 0.001),
      u("cm", "Centímetros", "cm", 0.01),
      u("m", "Metros", "m", 1),
      u("km", "Quilômetros", "km", 1000),
      u("in", "Polegadas", "pol", 0.0254),
      u("ft", "Pés", "pés", 0.3048),
      u("yd", "Jardas", "jd", 0.9144),
      u("mi", "Milhas", "mi", 1609.344),
      u("nmi", "Milhas náuticas", "mn", 1852),
    ],
  },
  {
    id: "mass",
    title: "Massa",
    pair: { from: "kg", to: "lb" },
    units: [
      u("mg", "Miligramas", "mg", 1e-6),
      u("g", "Gramas", "g", 0.001),
      u("kg", "Quilos", "kg", 1),
      u("t", "Toneladas", "t", 1000),
      u("oz", "Onças", "oz", 0.028349523125),
      u("lb", "Libras", "lb", 0.45359237),
      u("st", "Stones", "st", 6.35029318),
    ],
  },
  {
    id: "temperature",
    title: "Temperatura",
    pair: { from: "c", to: "f" },
    units: [u("c", "Celsius", "°C"), u("f", "Fahrenheit", "°F"), u("k", "Kelvin", "K")],
  },
  {
    id: "volume",
    title: "Volume",
    pair: { from: "l", to: "gal" },
    units: [
      u("ml", "Mililitros", "ml", 0.001),
      u("l", "Litros", "l", 1),
      u("m3", "Metros cúbicos", "m³", 1000),
      u("tsp", "Colheres de chá", "c. chá", 0.00492892159375),
      u("tbsp", "Colheres de sopa", "c. sopa", 0.01478676478125),
      u("cup", "Xícaras", "xíc.", 0.24),
      u("floz", "Onças líquidas", "fl oz", 0.0295735295625),
      u("gal", "Galões (EUA)", "gal", 3.785411784),
      u("galuk", "Galões (RU)", "gal RU", 4.54609),
    ],
  },
  {
    id: "speed",
    title: "Velocidade",
    pair: { from: "kmh", to: "mph" },
    units: [u("mps", "Metros por segundo", "m/s", 1), u("kmh", "Quilômetros por hora", "km/h", 1 / 3.6), u("mph", "Milhas por hora", "mph", 0.44704), u("kn", "Nós", "nós", 1852 / 3600)],
  },
  {
    id: "area",
    title: "Área",
    pair: { from: "m2", to: "ft2" },
    units: [
      u("cm2", "Centímetros quadrados", "cm²", 1e-4),
      u("m2", "Metros quadrados", "m²", 1),
      u("ha", "Hectares", "ha", 1e4),
      u("km2", "Quilômetros quadrados", "km²", 1e6),
      u("ft2", "Pés quadrados", "pés²", 0.09290304),
      u("ac", "Acres", "ac", 4046.8564224),
      u("mi2", "Milhas quadradas", "mi²", 2589988.110336),
    ],
  },
  {
    id: "data",
    title: "Dados",
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
    title: "Tempo",
    pair: { from: "h", to: "min" },
    units: [
      u("ms", "Milissegundos", "ms", 0.001),
      u("s", "Segundos", "s", 1),
      u("min", "Minutos", "min", 60),
      u("h", "Horas", "h", 3600),
      u("d", "Dias", "d", 86400),
      u("wk", "Semanas", "sem", 604800),
      // The Gregorian average year, 365,2425 days, like the app.
      u("yr", "Anos", "anos", 31556952),
    ],
  },
  {
    id: "currency",
    title: "Moeda",
    pair: { from: "BRL", to: "USD" },
    units: [
      u("BRL", "Real brasileiro", "BRL"),
      u("USD", "Dólar americano", "USD"),
      u("EUR", "Euro", "EUR"),
      u("GBP", "Libra esterlina", "GBP"),
      u("JPY", "Iene japonês", "JPY"),
      u("CAD", "Dólar canadense", "CAD"),
      u("AUD", "Dólar australiano", "AUD"),
      u("CHF", "Franco suíço", "CHF"),
      u("CNY", "Yuan chinês", "CNY"),
      u("MXN", "Peso mexicano", "MXN"),
    ],
  },
];

export function category(id: CategoryId): Category {
  return categories.find((entry) => entry.id === id) ?? categories[0]!;
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
 * A result as people read it: "1,6093", "12.345,7", "0,0006214" (ConverterNumber.format).
 * Around six significant digits, never trailing zeros; money always shows cents.
 */
export function formatNumber(value: number, isCurrency = false): string {
  if (!Number.isFinite(value)) return "—";
  if (value === 0) return "0";
  const magnitude = Math.abs(value);
  if (magnitude >= 1e15 || magnitude < 1e-9) return new Intl.NumberFormat("pt-BR", { notation: "scientific", maximumSignificantDigits: 4 }).format(value);
  if (isCurrency && magnitude >= 0.01) return new Intl.NumberFormat("pt-BR", { minimumFractionDigits: 2, maximumFractionDigits: 2 }).format(value);
  if (magnitude >= 1) {
    const integerDigits = Math.floor(Math.log10(magnitude)) + 1;
    return new Intl.NumberFormat("pt-BR", { maximumFractionDigits: Math.max(0, Math.min(4, 6 - integerDigits)) }).format(value);
  }
  return new Intl.NumberFormat("pt-BR", { maximumSignificantDigits: 4 }).format(value);
}
