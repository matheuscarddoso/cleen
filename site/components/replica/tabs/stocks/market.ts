/**
 * The replica's market: a fixed catalog of public tickers with made-up but plausible
 * prices, and their intraday lines as seeded random walks, so the server and the first
 * client render draw the same day. Numbers are written the way Ações writes them
 * (StockFormat): in Portuguese `R$ 58,83`, `US$ 347,72`, an index in points, `+0,76%`;
 * in English `R$58.83`, `$347.72`, `204,128.40`, `+0.76%`.
 */

import type { Lang } from "@/lib/lang";

export type Listing = {
  /** As the list shows it (StockSymbol.display): no `^`, no `.SA`. */
  symbol: string;
  name: string;
  /** Yahoo's exchDisp, shown on the search hit. */
  exchange: string;
  /** Null for an index: points, not money. */
  currency: "BRL" | "USD" | null;
  /** Yesterday's close on the first day the replica opens on. */
  close: number;
  /** Typical move per five-minute bar, as a fraction. */
  volatility: number;
  /** Where the first day leans, as a fraction over the session. */
  trend: number;
};

export const catalog: readonly Listing[] = [
  { symbol: "BVSP", name: "IBOVESPA", exchange: "São Paulo", currency: null, close: 204_128.4, volatility: 0.0009, trend: 0.0062 },
  { symbol: "AAPL", name: "Apple Inc.", exchange: "NASDAQ", currency: "USD", close: 348.21, volatility: 0.0012, trend: -0.002 },
  { symbol: "NVDA", name: "NVIDIA Corporation", exchange: "NASDAQ", currency: "USD", close: 212.21, volatility: 0.0019, trend: -0.006 },
  { symbol: "PETR4", name: "Petróleo Brasileiro S.A. - Petrobras", exchange: "São Paulo", currency: "BRL", close: 57.83, volatility: 0.0016, trend: 0.016 },
  { symbol: "PETR3", name: "Petróleo Brasileiro S.A. - Petrobras", exchange: "São Paulo", currency: "BRL", close: 61.2, volatility: 0.0015, trend: 0.012 },
  { symbol: "VALE3", name: "Vale S.A.", exchange: "São Paulo", currency: "BRL", close: 61.42, volatility: 0.0015, trend: 0.009 },
  { symbol: "VALE", name: "Vale S.A.", exchange: "NYSE", currency: "USD", close: 11.38, volatility: 0.0016, trend: 0.008 },
  { symbol: "MSFT", name: "Microsoft Corporation", exchange: "NASDAQ", currency: "USD", close: 512.4, volatility: 0.0011, trend: 0.007 },
  { symbol: "MSFT34", name: "Microsoft Corporation", exchange: "São Paulo", currency: "BRL", close: 92.15, volatility: 0.0012, trend: 0.006 },
  { symbol: "ITUB4", name: "Itaú Unibanco Holding S.A.", exchange: "São Paulo", currency: "BRL", close: 38.9, volatility: 0.0011, trend: 0.004 },
  { symbol: "BBAS3", name: "Banco do Brasil S.A.", exchange: "São Paulo", currency: "BRL", close: 22.15, volatility: 0.0013, trend: -0.005 },
  { symbol: "WEGE3", name: "WEG S.A.", exchange: "São Paulo", currency: "BRL", close: 44.8, volatility: 0.0013, trend: 0.003 },
  { symbol: "ABEV3", name: "Ambev S.A.", exchange: "São Paulo", currency: "BRL", close: 13.05, volatility: 0.001, trend: -0.002 },
  { symbol: "IVVB11", name: "iShares S&P 500 FIC FI em Cotas de Fundo de Índice", exchange: "São Paulo", currency: "BRL", close: 395.6, volatility: 0.0008, trend: 0.003 },
  { symbol: "GOOGL", name: "Alphabet Inc.", exchange: "NASDAQ", currency: "USD", close: 248.3, volatility: 0.0014, trend: 0.005 },
  { symbol: "AMZN", name: "Amazon.com, Inc.", exchange: "NASDAQ", currency: "USD", close: 221.7, volatility: 0.0014, trend: -0.003 },
  { symbol: "TSLA", name: "Tesla, Inc.", exchange: "NASDAQ", currency: "USD", close: 438.1, volatility: 0.0028, trend: 0.011 },
  { symbol: "META", name: "Meta Platforms, Inc.", exchange: "NASDAQ", currency: "USD", close: 712.4, volatility: 0.0016, trend: 0.004 },
  { symbol: "V", name: "Visa Inc.", exchange: "NYSE", currency: "USD", close: 344.9, volatility: 0.0009, trend: 0.002 },
];

/**
 * Tickers only the English page offers: the US index that stands in for the Ibovespa,
 * and Alphabet's other class, so typing "GOOG" finds two like "VALE" does.
 */
const englishOnly = {
  GSPC: { symbol: "GSPC", name: "S&P 500", exchange: "SNP", currency: null, close: 7_184.6, volatility: 0.0007, trend: 0.0048 },
  GOOG: { symbol: "GOOG", name: "Alphabet Inc.", exchange: "NASDAQ", currency: "USD", close: 249.6, volatility: 0.0014, trend: 0.005 },
} as const satisfies Record<string, Listing>;

/** What each page's search knows: the Portuguese catalog as it was, the English one with its extras in place. */
const catalogs: Record<Lang, readonly Listing[]> = {
  pt: catalog,
  en: [englishOnly.GSPC, ...catalog.flatMap((item) => (item.symbol === "GOOGL" ? [item, englishOnly.GOOG] : [item]))],
};

export function catalogFor(lang: Lang): readonly Listing[] {
  return catalogs[lang];
}

/**
 * The app's first-run list (StockSymbol.defaultWatchlist), Portuguese. The English page
 * opens on the US equivalents: the S&P 500 for the Ibovespa, Tesla for Petrobras.
 */
export const defaultWatchlist = ["BVSP", "AAPL", "NVDA", "PETR4"] as const;

export const defaultWatchlists: Record<Lang, readonly string[]> = { pt: defaultWatchlist, en: ["GSPC", "AAPL", "NVDA", "TSLA"] };

/** More than this stops reading as a glance (StockSymbol.maximumCount). */
export const maximumCount = 16;

/** One session in five-minute bars: 10:00 to 16:30. */
export const sessionLength = 78;

const bySymbol = new Map(catalogs.en.map((listing) => [listing.symbol, listing]));

export function listing(symbol: string): Listing | undefined {
  return bySymbol.get(symbol);
}

/** Small, fast and seedable (mulberry32): the same seed walks the same day. */
export function random(seed: number): () => number {
  let state = seed >>> 0;
  return () => {
    state = (state + 0x6d2b79f5) >>> 0;
    let t = state;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function hash(text: string): number {
  let value = 2166136261;
  for (const char of text) value = Math.imul(value ^ char.charCodeAt(0), 16777619);
  return value >>> 0;
}

/** A normal draw from two uniform ones (Box–Muller). */
function gaussian(next: () => number): number {
  const u = Math.max(next(), 1e-9);
  return Math.sqrt(-2 * Math.log(u)) * Math.cos(2 * Math.PI * next());
}

export type Day = { previousClose: number; closes: number[] };

/**
 * A whole session for one ticker: an opening gap, then a walk that leans toward the
 * day's trend, with the odd jump, so the lines read like real intraday charts.
 */
export function walkDay(item: Listing, previousClose: number, day: number): Day {
  const next = random(hash(item.symbol) ^ Math.imul(day + 1, 2654435761));
  // Later days pick their own lean; the first keeps the catalog's, so the still frame is known.
  const trend = day === 0 ? item.trend : (next() - 0.5) * item.volatility * 14;
  const volatility = item.volatility * 0.6;
  let price = previousClose * (1 + gaussian(next) * volatility * 1.6);
  const closes: number[] = [];
  for (let bar = 0; bar < sessionLength; bar += 1) {
    const jump = next() < 0.04 ? gaussian(next) * volatility * 3.5 : 0;
    // Drifts toward the day's lean, so a walk can't wander off into a crash.
    const aim = previousClose * (1 + (trend * (bar + 1)) / sessionLength);
    price *= 1 + ((aim - price) / price) * 0.08 + gaussian(next) * volatility + jump;
    closes.push(price);
  }
  return { previousClose, closes };
}

export type Market = { day: number; days: Record<string, Day> };

/** Every catalog ticker's session on day `day`, each opening from its last close. */
export function marketDay(day: number, previous?: Market): Market {
  const days: Record<string, Day> = {};
  // Every ticker either page can show; each walk is seeded by its own symbol, so the
  // extras leave the others' days exactly as they were.
  for (const item of catalogs.en) {
    const before = previous?.days[item.symbol];
    const close = before ? (before.closes[before.closes.length - 1] ?? item.close) : item.close;
    days[item.symbol] = walkDay(item, close, day);
  }
  return { day, days };
}

/** The first day, computed once at load so SSR and hydration share it. */
export const firstDay = marketDay(0);

export type Quote = {
  price: number;
  previousClose: number;
  change: number;
  /** Rounded to 0,01% first, as StockFormat.change does, so a tiny loss isn't "-0,00%". */
  direction: "up" | "down" | "flat";
  /** The bars so far, for the sparkline. */
  closes: number[];
};

export function quote(day: Day, revealed: number): Quote {
  const closes = day.closes.slice(0, Math.max(1, revealed));
  const price = closes[closes.length - 1] ?? day.previousClose;
  const change = price / day.previousClose - 1;
  const rounded = Math.round(change * 10_000);
  return { price, previousClose: day.previousClose, change, direction: rounded > 0 ? "up" : rounded < 0 ? "down" : "flat", closes };
}

// MARK: Formatting (pt-BR and en-US, written by hand so server and browser print the same thing)

export function number(value: number, digits = 2, lang: Lang = "pt"): string {
  const [whole = "0", fraction] = Math.abs(value).toFixed(digits).split(".");
  const [group, decimal] = lang === "en" ? [",", "."] : [".", ","];
  const grouped = whole.replace(/\B(?=(\d{3})+(?!\d))/g, group);
  return `${value < 0 ? "-" : ""}${grouped}${fraction ? `${decimal}${fraction}` : ""}`;
}

export function price(value: number, currency: Listing["currency"], lang: Lang = "pt"): string {
  if (lang === "en") {
    if (currency === "BRL") return `R$${number(value, 2, lang)}`;
    if (currency === "USD") return `$${number(value, 2, lang)}`;
    return number(value, 2, lang);
  }
  if (currency === "BRL") return `R$ ${number(value)}`;
  if (currency === "USD") return `US$ ${number(value)}`;
  return number(value);
}

export function change(fraction: number, lang: Lang = "pt"): string {
  const rounded = Math.round(fraction * 10_000) / 100;
  if (rounded === 0) return lang === "en" ? "0.00%" : "0,00%";
  return `${rounded > 0 ? "+" : "-"}${number(Math.abs(rounded), 2, lang)}%`;
}

export function absoluteChange(value: number, lang: Lang = "pt"): string {
  const rounded = Math.round(value * 100) / 100;
  if (rounded === 0) return lang === "en" ? "0.00" : "0,00";
  return `${rounded > 0 ? "+" : "-"}${number(Math.abs(rounded), 2, lang)}`;
}

// MARK: Search

function fold(text: string): string {
  return text.normalize("NFD").replace(/[̀-ͯ]/g, "").toLowerCase();
}

/** What Yahoo's search would answer, from the catalog: ticker prefix or a word of the name. */
export function search(query: string, lang: Lang = "pt"): Listing[] {
  const wanted = fold(query.trim());
  if (!wanted) return [];
  const known = catalogs[lang];
  const tickers = known.filter((item) => fold(item.symbol).startsWith(wanted));
  const names = known.filter((item) => !tickers.includes(item) && fold(item.name).split(/[\s.,-]+/).some((word) => word.startsWith(wanted)));
  return [...tickers, ...names].slice(0, 6);
}

/** The typed text as a ticker, or null when it can't be one (StockSymbol.lookup). */
export function lookup(query: string): string | null {
  const symbol = query.trim().toUpperCase().replace(/\.SA$/, "").replace(/^\^/, "");
  return /^[A-Z0-9=-]{1,12}$/.test(symbol) ? symbol : null;
}
