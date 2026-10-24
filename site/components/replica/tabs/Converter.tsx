"use client";

import { useEffect, useRef, useState } from "react";
import { useDemo, useTypewriter } from "../DemoContext";
import { notch } from "../style";
import { CategoryBar, ConverterBox, SwapButton, UnitMenu } from "./converter/parts";
import { category, convert, formatNumber, parseNumber, type CategoryId, type Unit } from "./converter/units";
import { copyText, useBeats, useConfirmation } from "./emoji/shared";

type Pair = { from: string; to: string };

/** Everything the visitor can change: the category, and per category what's typed and the pair. */
type State = { category: CategoryId; inputs: Partial<Record<CategoryId, string>>; pairs: Partial<Record<CategoryId, Pair>> };

/** Three conversions, typed one after another, each in its own category. */
const script: readonly { category: CategoryId; typed: string; beats: readonly number[] }[] = [
  { category: "length", typed: "42", beats: [4000] },
  // Moeda: the amount, then the swap turns BRL → USD into USD → BRL.
  { category: "currency", typed: "250", beats: [1300, 2700] },
  // Temperatura: the result, then Return copies it.
  { category: "temperature", typed: "36,6", beats: [900, 1500, 1600] },
];
const typed = script.map((entry) => entry.typed);

/** The ECB publishes on weekdays: the last one before today, as "22 de out.". */
function lastPublication(now: Date): string {
  const day = new Date(now);
  do day.setDate(day.getDate() - 1);
  while (day.getDay() === 0 || day.getDay() === 6);
  return new Intl.DateTimeFormat("pt-BR", { day: "numeric", month: "short" }).format(day);
}

/** Half a turn of the swap's arrows (the glyph reads the same upside down). */
function turn(element: HTMLElement | null) {
  element?.animate([{ transform: "rotate(0deg)" }, { transform: "rotate(180deg)" }], { duration: 380, easing: "cubic-bezier(0.32, 0.72, 0, 1)" });
}

/** The result's size: the app lets it shrink to 45% before it would overflow the box. */
function resultSize(text: string): number {
  const room = 252;
  const width = [...text].reduce((sum, char) => sum + (/[0-9]/.test(char) ? 0.62 : char === "—" ? 1 : 0.3), 0) * 24;
  return width <= room ? 24 : Math.max(24 * 0.45, (24 * room) / width);
}

/**
 * Conversor, as NotchConverterTab lays it out: the categories on top, then the value
 * you type and its conversion side by side with the swap between them, and the rate
 * underneath. Typing converts live; Return (or the copy button) copies the result.
 */
export function ConverterTab() {
  const { reduced } = useDemo();
  const typing = useTypewriter(typed, { speed: 150, hold: 4200 });
  const [manual, setManual] = useState<State | null>(null);
  const [copied, showCopied] = useConfirmation<true>(1400);
  const [published, setPublished] = useState<string | null>(null);
  const glyph = useRef<HTMLSpanElement>(null);

  const index = reduced ? 0 : typing.index;
  const step = script[index] ?? script[0]!;
  const beat = useBeats(!manual && !reduced && typing.finished ? String(index) : null, step.beats);
  const scripted: State = {
    category: step.category,
    inputs: { [step.category]: reduced ? step.typed : typing.text },
    pairs: step.category === "currency" && beat >= 1 ? { currency: { from: "USD", to: "BRL" } } : {},
  };
  const state = manual ?? scripted;
  const kind = category(state.category);
  const pair = state.pairs[state.category] ?? kind.pair;
  const pick = (id: string, fallback: number): Unit => kind.units.find((unit) => unit.id === id) ?? kind.units[fallback]!;
  const from = pick(pair.from, 0);
  const to = pick(pair.to, 1);
  const input = state.inputs[state.category] ?? "1";
  const value = parseNumber(input);
  const result = value === null ? null : convert(value, from, to, kind.id);
  const isCurrency = kind.id === "currency";
  const resultText = result === null ? "—" : formatNumber(result, isCurrency);
  const rate = from.id === to.id ? null : convert(1, from, to, kind.id);
  const rateText = rate === null ? null : `1 ${from.symbol} = ${formatNumber(rate)} ${to.symbol}`;
  const showCopiedBadge = manual ? copied !== null : step.category === "temperature" && beat === 1;

  useEffect(() => setPublished(lastPublication(new Date())), []);

  const swappedByScript = !manual && step.category === "currency" && beat >= 1;
  useEffect(() => {
    if (swappedByScript) turn(glyph.current);
  }, [swappedByScript]);

  const update = (change: (current: State) => State) => setManual(change(manual ?? scripted));
  const setPair = (next: Pair) => update((current) => ({ ...current, pairs: { ...current.pairs, [current.category]: next } }));
  const copyResult = () => {
    if (result === null) return;
    update((current) => current);
    showCopied(true);
    void copyText(resultText);
  };

  return (
    <div className="flex h-full flex-col gap-2.5">
      <CategoryBar selected={state.category} onSelect={(id) => update((current) => ({ ...current, category: id }))} />
      <div className="flex min-h-0 flex-1 gap-2">
        <ConverterBox
          unit={
            <UnitMenu
              units={kind.units}
              selected={from}
              // Picking the unit on the other side swaps them instead of converting into itself.
              onSelect={(id) => setPair({ from: id, to: id === to.id ? from.id : to.id })}
            />
          }
        >
          <span className="relative block">
            <input
              value={input}
              onChange={(event) => update((current) => ({ ...current, inputs: { ...current.inputs, [current.category]: event.target.value } }))}
              onKeyDown={(event) => {
                if (event.key === "Enter") {
                  event.preventDefault();
                  copyResult();
                }
              }}
              placeholder="0"
              inputMode="decimal"
              autoComplete="off"
              spellCheck={false}
              aria-label={`Valor em ${from.name}`}
              className="block h-[29px] w-full bg-transparent text-[24px] font-semibold tabular-nums outline-none placeholder:text-white/25"
              style={{ color: value === null && input.length > 0 ? notch.critical : notch.primary }}
            />
            {!manual && !reduced && (
              <span aria-hidden className="pointer-events-none absolute inset-y-0 left-0 flex items-center whitespace-pre text-[24px] font-semibold tabular-nums text-transparent">
                {input}
                <span className="ml-px h-[26px] w-[2px] rounded-full bg-white" />
              </span>
            )}
          </span>
        </ConverterBox>
        <SwapButton
          glyph={glyph}
          onSwap={() => {
            if (!reduced) turn(glyph.current);
            setPair({ from: to.id, to: from.id });
          }}
        />
        <ConverterBox
          unit={<UnitMenu units={kind.units} selected={to} onSelect={(id) => setPair({ from: id === from.id ? to.id : from.id, to: id })} />}
          copy={result === null ? undefined : { copied: showCopiedBadge, live: manual !== null, onCopy: copyResult }}
        >
          <output aria-live={manual ? "polite" : "off"} aria-label={`${resultText} ${to.name}`} className="flex h-[29px] items-center overflow-hidden whitespace-nowrap">
            <span
              key={resultText}
              className="animate-[numeric_180ms_ease-out] font-semibold leading-none tabular-nums"
              style={{ fontSize: resultSize(resultText), color: result === null ? notch.tertiary : notch.primary }}
            >
              {resultText}
            </span>
          </output>
        </ConverterBox>
      </div>
      <div className="flex shrink-0 items-center gap-2 whitespace-nowrap text-[10.5px] leading-[13px]" style={{ color: notch.tertiary }}>
        {rateText && (
          <span key={rateText} className="animate-[numeric_180ms_ease-out] tabular-nums">
            {rateText}
          </span>
        )}
        <span className="flex-1" />
        {isCurrency ? (
          <span title="Taxas de referência do Banco Central Europeu, via Frankfurter">{published ? `Cotação de ${published} · BCE` : "Cotação do BCE"}</span>
        ) : (
          <span>Return copia o resultado</span>
        )}
      </div>
    </div>
  );
}
