"use client";

import { MapPin, Search, X } from "lucide-react";
import { useState } from "react";
import { HeaderButton } from "../Panel";
import { useSteps } from "../DemoContext";
import { notch } from "../style";

type Sky = "sun" | "partly" | "cloud" | "rain" | "storm";

type Place = {
  name: string;
  temperature: number;
  sky: Sky;
  description: string;
  feels: number;
  humidity: number;
  week: { day: string; sky: Sky; high: number; low: number; chance?: number }[];
};

const places: Place[] = [
  {
    name: "São Paulo",
    temperature: 22,
    sky: "cloud",
    description: "Nublado",
    feels: 24,
    humidity: 79,
    week: [
      { day: "Hoje", sky: "cloud", high: 24, low: 17 },
      { day: "Sex", sky: "rain", high: 21, low: 16, chance: 80 },
      { day: "Sáb", sky: "storm", high: 23, low: 17, chance: 65 },
      { day: "Dom", sky: "partly", high: 26, low: 17 },
      { day: "Seg", sky: "sun", high: 28, low: 18 },
      { day: "Ter", sky: "sun", high: 29, low: 19 },
      { day: "Qua", sky: "partly", high: 27, low: 18, chance: 20 },
    ],
  },
  {
    name: "Lisboa",
    temperature: 18,
    sky: "sun",
    description: "Céu limpo",
    feels: 17,
    humidity: 62,
    week: [
      { day: "Hoje", sky: "sun", high: 21, low: 13 },
      { day: "Sex", sky: "sun", high: 22, low: 14 },
      { day: "Sáb", sky: "partly", high: 20, low: 14 },
      { day: "Dom", sky: "rain", high: 17, low: 12, chance: 70 },
      { day: "Seg", sky: "cloud", high: 18, low: 12, chance: 30 },
      { day: "Ter", sky: "partly", high: 19, low: 12 },
      { day: "Qua", sky: "sun", high: 21, low: 13 },
    ],
  },
  {
    name: "Tóquio",
    temperature: 15,
    sky: "rain",
    description: "Chuva fraca",
    feels: 13,
    humidity: 88,
    week: [
      { day: "Hoje", sky: "rain", high: 16, low: 11, chance: 90 },
      { day: "Sex", sky: "cloud", high: 17, low: 11, chance: 40 },
      { day: "Sáb", sky: "partly", high: 19, low: 12 },
      { day: "Dom", sky: "sun", high: 20, low: 13 },
      { day: "Seg", sky: "sun", high: 21, low: 13 },
      { day: "Ter", sky: "partly", high: 19, low: 12, chance: 20 },
      { day: "Qua", sky: "rain", high: 16, low: 11, chance: 75 },
    ],
  },
];

/** São Paulo, then a hover across the week, then the city search swapping to Lisboa and Tóquio. */
const script = [2600, 1400, 1800, 2600, 1400, 1800, 2600] as const;

/**
 * Tempo, as NotchWeatherTab lays it out: now on the left in one large light figure, a
 * hairline, then the week as seven columns. The magnifier swaps the week for the search.
 */
export function WeatherTab() {
  const [step] = useSteps(script);
  const [manual, setManual] = useState<{ place: number; searching: boolean } | null>(null);
  // The script: 0 SP, 1 search open, 2 Lisboa picked, 3 Lisboa, 4 search, 5 Tóquio, 6 Tóquio.
  const scripted = { place: step < 2 ? 0 : step < 5 ? 1 : 2, searching: step === 1 || step === 4 };
  const state = manual ?? scripted;
  const place = places[state.place] ?? places[0]!;
  const choose = (index: number) => setManual({ place: index, searching: false });

  return (
    <div className="flex h-full items-start gap-4 pt-1">
      <div className="w-[176px] shrink-0 pl-1">
        <div className="-ml-px flex items-center gap-0.5">
          <span className="truncate text-[12px] font-medium" style={{ color: notch.secondary }}>{place.name}</span>
          <HeaderButton
            icon={state.searching ? X : Search}
            label={state.searching ? "Fechar a busca" : "Trocar de cidade"}
            active={state.searching}
            onClick={() => setManual({ place: state.place, searching: !state.searching })}
          />
        </div>
        <div className="-ml-1 mt-0.5 flex items-center gap-2">
          <WeatherGlyph sky={place.sky} size={32} />
          <span key={place.name} className="animate-[numeric_300ms_ease-out] text-[44px] font-light leading-none tabular-nums">{place.temperature}°</span>
        </div>
        <p className="mt-1 text-[12px] font-medium text-white/85">{place.description}</p>
        <p className="mt-0.5 text-[10.5px]" style={{ color: notch.tertiary }}>
          Sensação {place.feels}° · Umidade {place.humidity}%
        </p>
      </div>
      <div className="w-px self-stretch" style={{ background: notch.separator }} />
      <div className="relative min-w-0 flex-1 self-stretch">
        {state.searching ? (
          <CitySearch typed={manual ? "" : step === 1 ? "Lisboa" : "Tóquio"} onPick={choose} />
        ) : (
          <div className="flex gap-0.5">
            {place.week.map((day, index) => (
              <DayColumn key={`${place.name}-${day.day}`} {...day} today={index === 0} highlighted={!manual && step === 0 && index === 2} />
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

function DayColumn({ day, sky, high, low, chance, today, highlighted }: Place["week"][number] & { today: boolean; highlighted: boolean }) {
  return (
    <div
      className="flex flex-1 flex-col items-center gap-1 rounded-[10px] py-2 transition-colors duration-150 hover:bg-white/[0.06]"
      style={{ background: highlighted ? "rgba(255,255,255,0.06)" : today ? notch.card : undefined }}
      title={`${day}: máxima ${high}°, mínima ${low}°`}
    >
      <span className="text-[11px] font-medium" style={{ color: today ? notch.primary : notch.secondary }}>{day}</span>
      <span className="pt-0.5"><WeatherGlyph sky={sky} size={19} /></span>
      <span className="h-3 text-[9.5px] font-medium tabular-nums" style={{ color: notch.secondary }}>{chance ? `${chance}%` : " "}</span>
      <span className="flex flex-col items-center gap-px">
        <span className="text-[13px] font-semibold tabular-nums">{high}°</span>
        <span className="text-[12px] tabular-nums" style={{ color: notch.secondary }}>{low}°</span>
      </span>
    </div>
  );
}

/** The city search that opens in the week's place (WeatherSearchPanel). */
function CitySearch({ typed, onPick }: { typed: string; onPick: (index: number) => void }) {
  const [query, setQuery] = useState(typed);
  const shown = query.trim().length > 0 ? places.map((place, index) => ({ place, index })).filter(({ place }) => place.name.toLowerCase().startsWith(query.trim().toLowerCase().slice(0, 2))) : [];
  return (
    <div className="flex h-full flex-col gap-1.5">
      <div className="flex gap-1.5">
        <label className="flex h-[26px] flex-1 items-center gap-1.5 rounded-[8px] px-2" style={{ background: notch.control }}>
          <Search size={11} className="shrink-0" style={{ color: notch.secondary }} aria-hidden />
          <input
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            placeholder="Buscar cidade"
            aria-label="Buscar cidade"
            className="w-full bg-transparent text-[12px] text-white outline-none placeholder:text-white/35"
          />
        </label>
        <button type="button" className="flex h-[26px] items-center gap-1 rounded-full bg-white px-2.5 text-[11px] font-medium text-black" onClick={() => onPick(0)}>
          <MapPin size={11} aria-hidden /> Usar minha localização
        </button>
      </div>
      {shown.length === 0 ? (
        <p className="px-1 text-[10.5px]" style={{ color: notch.tertiary }}>Digite o nome de uma cidade.</p>
      ) : (
        shown.map(({ place, index }) => (
          <button key={place.name} type="button" onClick={() => onPick(index)} className="flex items-center justify-between rounded-[8px] px-2 py-1.5 text-left text-[12px] hover:bg-white/10" style={{ background: notch.card }}>
            <span className="font-medium">{place.name}</span>
            <span className="flex items-center gap-1.5" style={{ color: notch.secondary }}>
              <WeatherGlyph sky={place.sky} size={13} /> {place.temperature}°
            </span>
          </button>
        ))
      )}
    </div>
  );
}

/** The sky in the symbol's own colours: yellow sun, white cloud, blue drops (SF multicolor). */
export function WeatherGlyph({ sky, size }: { sky: Sky; size: number }) {
  const sun = "#ffd60a";
  const cloud = "#f2f2f7";
  const drop = "#64d2ff";
  const cloudPath = "M7 19h10.5a4.5 4.5 0 0 0 .6-8.96A6 6 0 0 0 6.6 9.2 5 5 0 0 0 7 19Z";
  return (
    <svg viewBox="0 0 24 24" width={size * 1.15} height={size} aria-hidden>
      {sky === "sun" && (
        <g>
          <circle cx="12" cy="12" r="4.6" fill={sun} />
          {Array.from({ length: 8 }, (_, ray) => {
            const angle = (ray * Math.PI) / 4;
            return <line key={ray} x1={12 + Math.cos(angle) * 7} y1={12 + Math.sin(angle) * 7} x2={12 + Math.cos(angle) * 9.4} y2={12 + Math.sin(angle) * 9.4} stroke={sun} strokeWidth="1.8" strokeLinecap="round" />;
          })}
        </g>
      )}
      {sky === "partly" && (
        <g>
          <circle cx="15.5" cy="7.5" r="4" fill={sun} />
          <path d={cloudPath} fill={cloud} transform="translate(-1.5 1.5) scale(0.95)" />
        </g>
      )}
      {sky === "cloud" && <path d={cloudPath} fill={cloud} transform="translate(0 -1.5)" />}
      {(sky === "rain" || sky === "storm") && (
        <g>
          <path d={cloudPath} fill={cloud} transform="translate(0 -5) scale(1)" />
          {sky === "rain" ? (
            [8, 12, 16].map((x) => <line key={x} x1={x} y1="17" x2={x - 1.2} y2="21.5" stroke={drop} strokeWidth="1.8" strokeLinecap="round" />)
          ) : (
            <path d="M12.5 15.5 10 19.5h3l-1.5 4" fill="none" stroke={sun} strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" />
          )}
        </g>
      )}
    </svg>
  );
}
