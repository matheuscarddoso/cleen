"use client";

import Image from "next/image";
import { useEffect, useState } from "react";
import { useL } from "./LangProvider";
import { useLoop } from "./useLoop";

/** The answers the launcher gives to plain Portuguese (or English), one row each, like its results. */
const answers = {
  pt: [
    { asked: "100 usd em brl", answer: "R$ 537,00", section: "Conversão" },
    { asked: "15h em Tóquio", answer: "03:00 em Tóquio", section: "Fuso horário" },
    { asked: "72 f em c", answer: "22,22 °C", section: "Conversão" },
    { asked: "hoje + 45 dias", answer: "", section: "Data" },
  ],
  en: [
    { asked: "100 eur to usd", answer: "$117.00", section: "Conversion" },
    { asked: "3pm in Tokyo", answer: "4:00 AM in Tokyo", section: "Time Zone" },
    { asked: "72 f to c", answer: "22.22 °C", section: "Conversion" },
    { asked: "today + 45 days", answer: "", section: "Date" },
  ],
} as const;

/** "Quinta, 10 de dezembro" / "Thursday, December 10": 45 days from the visitor's today. */
function inFortyFiveDays(locale: string) {
  const day = new Date();
  day.setDate(day.getDate() + 45);
  const text = new Intl.DateTimeFormat(locale, { weekday: "long", day: "numeric", month: "long" }).format(day).replace("-feira", "");
  return text.charAt(0).toUpperCase() + text.slice(1);
}

const answerSteps = [2200, 2200, 2200, 2200] as const;

/** The search's calculator going through money, a time zone, units and a date. */
export function SmartAnswers() {
  const l = useL();
  const { ref, index } = useLoop<HTMLDivElement>(answerSteps, 0);
  // The date is the visitor's, so it's worked out once the page is in their browser.
  const [date, setDate] = useState("");
  useEffect(() => setDate(inFortyFiveDays(l.locale)), [l.locale]);
  return (
    <div ref={ref} className="mx-auto w-full max-w-[340px] rounded-[16px] bg-black p-2 text-left text-white shadow-[0_18px_40px_rgba(0,0,0,0.18)]">
      {answers[l.lang].map((row, position) => {
        const active = position === index;
        return (
          <div
            key={row.asked}
            className="flex items-center gap-3 rounded-[10px] px-3 py-2.5 transition-colors duration-300"
            style={{ background: active ? "rgba(255,255,255,0.14)" : undefined }}
          >
            <span className="flex size-6 shrink-0 items-center justify-center rounded-[6px] text-[14px] font-semibold" style={{ background: "linear-gradient(180deg, rgb(255,166,51), rgb(255,148,0))" }} aria-hidden>
              =
            </span>
            <span className="flex min-w-0 flex-col">
              <span className="truncate text-[15px] font-medium tabular-nums">{row.answer || date || "…"}</span>
              <span className="truncate text-[12px] text-white/40">{row.asked}</span>
            </span>
            <span className={`ml-auto shrink-0 text-[12px] transition-colors duration-300 ${active ? "text-white/60" : "text-white/30"}`}>{active ? l("Copiar ⏎", "Copy ⏎") : row.section}</span>
          </div>
        );
      })}
    </div>
  );
}

const noSteps: readonly number[] = [];
const keyword = ";email";

/**
 * A snippet's keyword typed into a mail, then swapped for the text it stands for, as
 * if by hand: no menu, no paste.
 */
export function SnippetExpand() {
  const l = useL();
  const expansion = l("oi@exemplo.com", "hi@example.com");
  const { ref, running, reduced } = useLoop<HTMLDivElement>(noSteps, 0);
  const [typed, setTyped] = useState(0);
  const [expanded, setExpanded] = useState(false);
  useEffect(() => {
    if (reduced) {
      setExpanded(true);
      return;
    }
    if (!running) return;
    const timer = window.setTimeout(
      () => {
        if (expanded) {
          setExpanded(false);
          setTyped(0);
        } else if (typed < keyword.length) setTyped(typed + 1);
        else setExpanded(true);
      },
      expanded ? 2600 : typed === 0 ? 900 : typed === keyword.length ? 500 : 150,
    );
    return () => window.clearTimeout(timer);
  }, [expanded, reduced, running, typed]);

  return (
    <div ref={ref} className="mx-auto w-full max-w-[360px] overflow-hidden rounded-[14px] bg-white text-left shadow-[0_0_0_1px_rgba(0,0,0,0.06),0_18px_40px_rgba(0,0,0,0.12)]">
      <div className="flex items-center gap-1.5 border-b border-black/[0.06] bg-[#f6f6f8] px-3 py-2.5" aria-hidden>
        <span className="size-3 rounded-full bg-[#ff5f57]" />
        <span className="size-3 rounded-full bg-[#febc2e]" />
        <span className="size-3 rounded-full bg-[#28c840]" />
        <span className="ml-3 text-[13px] font-medium text-black/50">{l("Nova mensagem", "New Message")}</span>
      </div>
      <div className="space-y-2 px-4 py-4 text-[15px]">
        <p className="text-black/40">
          {l("Para: ", "To: ")}<span className="text-ink">{l("equipe@exemplo.com", "team@example.com")}</span>
        </p>
        <p className="border-t border-black/[0.06] pt-2 text-ink">{l("Oi, pessoal! Respondam neste e-mail:", "Hi all! Please reply to this address:")}</p>
        <p className="flex h-[22px] items-center text-ink" aria-label={expanded ? expansion : keyword}>
          {expanded ? (
            <span className="animate-[numeric_300ms_ease-out] rounded-[4px] bg-accent/10 px-1 text-accent">{expansion}</span>
          ) : (
            <span className="font-medium text-black/70">{keyword.slice(0, typed)}</span>
          )}
          <span className="ml-px inline-block h-[18px] w-[2px] animate-pulse rounded-full bg-accent motion-reduce:animate-none" />
        </p>
      </div>
    </div>
  );
}

/** Uso de IA: each tool's windows, with how much of each is gone. Only the tools you picked. */
const limits = {
  pt: [
    { tool: "Claude Code", logo: "/claude.svg", rows: [["Sessão", 0.05, "volta às 18:40"], ["Semanal", 0.32, "volta na quinta"]] },
    { tool: "Codex", logo: null, rows: [["Semanal", 0.18, "volta na segunda"]] },
  ],
  en: [
    { tool: "Claude Code", logo: "/claude.svg", rows: [["Session", 0.05, "resets at 6:40 PM"], ["Weekly", 0.32, "resets Thursday"]] },
    { tool: "Codex", logo: null, rows: [["Weekly", 0.18, "resets Monday"]] },
  ],
} as const;

export function AILimits() {
  const l = useL();
  return (
    <div className="mx-auto w-full max-w-[340px] rounded-[16px] bg-black p-4 text-left text-white shadow-[0_18px_40px_rgba(0,0,0,0.18)]">
      {limits[l.lang].map((group, position) => (
        <div key={group.tool} className={position > 0 ? "mt-4 border-t border-white/[0.08] pt-4" : ""}>
          <p className="flex items-center gap-2 text-[14px] font-medium">
            {group.logo ? (
              <Image src={group.logo} alt="" width={14} height={14} />
            ) : (
              <span className="flex size-3.5 items-center justify-center rounded-[4px] bg-white text-[9px] font-semibold text-black" aria-hidden>
                ›_
              </span>
            )}
            {group.tool}
          </p>
          {group.rows.map(([label, used, reset]) => (
            <div key={label} className="mt-2.5">
              <p className="flex justify-between text-[12px]">
                <span className="text-white/70">{label}</span>
                <span className="tabular-nums text-white/45">
                  {Math.round(used * 100)}% · {reset}
                </span>
              </p>
              <span className="mt-1.5 block h-[4px] overflow-hidden rounded-full bg-white/[0.12]">
                <span className="block h-full rounded-full bg-white/80" style={{ width: `${used * 100}%` }} />
              </span>
            </div>
          ))}
        </div>
      ))}
      <p className="mt-4 flex flex-wrap gap-1.5 text-[11px] font-medium">
        {[
          ["Claude Code", true],
          ["Codex", true],
          ["Cursor", false],
          ["Copilot", false],
          ["Grok", false],
        ].map(([name, on]) => (
          <span key={String(name)} className={`rounded-full px-2 py-0.5 ${on ? "bg-white/[0.16] text-white" : "text-white/35 shadow-[inset_0_0_0_1px_rgba(255,255,255,0.12)]"}`}>
            {name}
          </span>
        ))}
      </p>
    </div>
  );
}

/** A few commands with the shortcut someone gave them, under the launcher's own. */
export function CommandHotkeys() {
  const l = useL();
  const rows = [
    ["⌃⌥E", l("Buscar emoji", "Search emoji")],
    ["⌃⌥V", l("Histórico da área de transferência", "Clipboard history")],
    ["⌃⌥←", l("Metade esquerda", "Left Half")],
  ] as const;
  return (
    <ul className="mx-auto mt-8 max-w-[300px] space-y-2 text-left text-[14px]">
      {rows.map(([keys, name]) => (
        <li key={keys} className="flex items-center gap-3">
          <kbd className="min-w-[58px] rounded-[7px] border border-black/10 bg-gradient-to-b from-white to-[#ececf0] px-2 py-1 text-center font-sans text-[13px] font-medium text-ink shadow-[0_2px_4px_rgba(0,0,0,0.08)]">{keys}</kbd>
          <span className="truncate text-mute">{name}</span>
        </li>
      ))}
    </ul>
  );
}
