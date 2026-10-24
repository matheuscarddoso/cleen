"use client";

import { ChevronRight, CircleCheck, CodeXml, File, Puzzle, Trash2, type LucideIcon } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { useDemo, useSteps } from "../DemoContext";
import { level, notch } from "../style";
import { bytes, cleaned, cleanSize, findings, formatPercent, rescanned, usedFraction, type Disk } from "./overview/disk";

/** Idle, the press, the scans landing one by one, Limpar, Confirmar, cleaning, the space back. */
const script = [2000, 220, 800, 650, 650, 2400, 220, 1500, 220, 1700, 4400] as const;

const idle: Disk = { phase: "idle", scanned: false, found: 0, armed: false, pressed: false, report: null, data: findings };

/** The script's state at each step; step 5 (results in, "Limpar 1,28 GB") is the still. */
function scripted(step: number): Disk {
  if (step <= 1) return { ...idle, pressed: step === 1 };
  if (step <= 4) return { ...idle, phase: "scanning", found: step - 2 };
  const ready: Disk = { ...idle, phase: "ready", scanned: true, found: 3 };
  if (step <= 6) return { ...ready, pressed: step === 6 };
  if (step <= 8) return { ...ready, armed: true, pressed: step === 8 };
  if (step === 9) return { ...ready, phase: "cleaning" };
  return { ...ready, report: cleanSize(findings), data: cleaned(findings) };
}

/**
 * Visão geral, as NotchOverviewTab lays it out: free space as one large light figure
 * with the one action under it, a hairline, then what can be cleaned. The script scans,
 * cleans with the two-step confirm, and the free space counts up; every button works.
 */
export function OverviewTab() {
  const { reduced } = useDemo();
  const [step] = useSteps(script, 5);
  const [manual, setManual] = useState<Disk | null>(null);
  const timers = useRef<number[]>([]);
  const disk = manual ?? scripted(step);
  const { data } = disk;

  useEffect(() => () => timers.current.forEach((timer) => window.clearTimeout(timer)), []);

  const later = (ms: number, update: (current: Disk) => Disk) => {
    timers.current.push(window.setTimeout(() => setManual((current) => (current ? update(current) : current)), ms));
  };
  const clearTimers = () => {
    timers.current.forEach((timer) => window.clearTimeout(timer));
    timers.current = [];
  };

  const scan = () => {
    clearTimers();
    setManual({ ...disk, phase: "scanning", found: 0, armed: false, pressed: false, report: null, data: rescanned(disk.data) });
    [700, 1300, 2000].forEach((ms, index) => later(ms, (current) => ({ ...current, found: index + 1, ...(index === 2 ? { phase: "ready", scanned: true } : {}) })));
  };

  // ConfirmingButton: the first tap arms it, the second cleans; it disarms after 4 s.
  const clean = () => {
    clearTimers();
    if (!disk.armed) {
      setManual({ ...disk, armed: true, pressed: false });
      later(4000, (current) => ({ ...current, armed: false }));
      return;
    }
    setManual({ ...disk, phase: "cleaning", armed: false, pressed: false });
    later(1700, (current) => ({ ...current, phase: "ready", report: cleanSize(current.data), data: cleaned(current.data) }));
  };

  const free = useCountUp(data.free, !reduced);
  const used = usedFraction(data);
  const busy = disk.phase === "scanning" || disk.phase === "cleaning";
  const value = (index: number, size: number) => (disk.phase === "scanning" ? (disk.found > index ? bytes(size) : "…") : disk.scanned ? bytes(size) : "—");

  return (
    <div className="flex h-full items-start gap-[18px] pt-1">
      <div className="flex w-[240px] shrink-0 flex-col gap-1.5 pl-1">
        <span className="text-[12px] font-medium leading-[14px]" style={{ color: notch.secondary }}>Disco</span>
        <span className="text-[34px] font-light leading-[41px] tabular-nums" aria-label={`${bytes(data.free)} livres`}>{bytes(free)}</span>
        <span className="text-[11px] leading-[13px] tabular-nums" style={{ color: notch.secondary }}>
          livres de {bytes(data.total)} · {formatPercent(used)} em uso
        </span>
        <div className="py-1">
          <div className="relative h-[3.5px] overflow-hidden rounded-full" style={{ background: notch.track }}>
            <div
              className="absolute inset-y-0 left-0 rounded-full transition-[width,background-color] duration-300 ease-out"
              style={{ width: `${used * 100}%`, background: level(used) }}
            />
          </div>
        </div>
        <div className="flex h-[26px] items-center gap-2">
          {busy ? (
            <span role="status" className="flex items-center gap-2 text-[11px]" style={{ color: notch.secondary }}>
              <Spinner />
              {disk.phase === "scanning" ? "Analisando…" : "Limpando…"}
            </span>
          ) : disk.scanned && cleanSize(data) > 0 ? (
            <Pill kind={disk.armed ? "destructive" : "primary"} pressed={disk.pressed} onClick={clean}>
              {disk.armed ? "Confirmar" : `Limpar ${bytes(cleanSize(data))}`}
            </Pill>
          ) : (
            <Pill kind="primary" pressed={disk.pressed} onClick={scan}>
              {disk.scanned ? "Analisar de novo" : "Analisar o Mac"}
            </Pill>
          )}
        </div>
        {disk.report !== null && !busy && (
          <p className="flex animate-[numeric_300ms_ease-out] items-center gap-1.5 text-[12px] font-medium leading-[14px] tabular-nums">
            <CircleCheck size={13} strokeWidth={2.4} style={{ color: notch.good }} aria-hidden />
            {bytes(disk.report)} liberados
          </p>
        )}
      </div>
      <div className="w-px self-stretch" style={{ background: notch.separator }} />
      <div
        className="min-w-0 flex-1 overflow-hidden rounded-[12px]"
        style={{ background: notch.card, boxShadow: `inset 0 0 0 1px ${notch.cardStroke}` }}
      >
        <MeterRow icon={Trash2} label="Lixo" value={value(0, data.junk)} />
        <Hairline />
        <MeterRow icon={CodeXml} label="Projetos parados" value={value(2, data.projects)} />
        <Hairline />
        <MeterRow icon={Puzzle} label="Restos de apps" value={value(1, data.orphans)} />
        <Hairline />
        {/* Not part of the smart scan: it stays a dash until its own tab looks. */}
        <MeterRow icon={File} label="Arquivos grandes" value="—" />
      </div>
    </div>
  );
}

/** NotchGroup's separator, inset past the icon. */
function Hairline() {
  return <div className="ml-9 h-px" style={{ background: notch.separator }} />;
}

/** NotchMeterRow with nothing in the middle: icon, label, the value, a chevron. */
function MeterRow({ icon: Icon, label, value }: { icon: LucideIcon; label: string; value: string }) {
  return (
    <div className="flex h-7 items-center gap-2.5 px-3">
      <span className="flex w-4 shrink-0 justify-center" style={{ color: notch.secondary }}>
        <Icon size={13} strokeWidth={2} aria-hidden />
      </span>
      <span className="truncate text-[12px] font-medium" style={{ color: "rgba(255,255,255,0.85)" }}>{label}</span>
      <span className="flex-1" />
      <span key={value} className="min-w-[70px] animate-[numeric_300ms_ease-out] text-right text-[11.5px] font-semibold tabular-nums">
        {value}
      </span>
      <ChevronRight size={11} strokeWidth={2.6} className="shrink-0" style={{ color: notch.tertiary }} aria-hidden />
    </div>
  );
}

/** NotchPillButtonStyle: the white pill, or the red one while confirming. */
function Pill({ kind, pressed, onClick, children }: { kind: "primary" | "destructive"; pressed: boolean; onClick: () => void; children: string }) {
  const primary = kind === "primary";
  return (
    <button
      type="button"
      onClick={onClick}
      className={`flex h-[26px] items-center rounded-full px-3 text-[12px] font-medium tabular-nums transition-[background-color,color,opacity,scale] duration-150 active:scale-[0.97] active:opacity-80 ${primary ? "bg-white text-black hover:bg-white/92" : "text-white hover:opacity-95"}`}
      style={{ background: primary ? undefined : notch.critical, scale: pressed ? 0.97 : undefined, opacity: pressed ? 0.8 : undefined }}
    >
      {children}
    </button>
  );
}

/** ProgressView at .small: eight spokes turning, white. */
function Spinner() {
  return (
    <svg viewBox="0 0 16 16" width={14} height={14} className="motion-safe:animate-spin [animation-duration:0.8s] [animation-timing-function:steps(8)]" aria-hidden>
      {Array.from({ length: 8 }, (_, spoke) => (
        <line
          key={spoke}
          x1="8"
          y1="1.8"
          x2="8"
          y2="4.6"
          stroke="#fff"
          strokeWidth="1.7"
          strokeLinecap="round"
          opacity={0.25 + (spoke / 7) * 0.75}
          transform={`rotate(${spoke * 45} 8 8)`}
        />
      ))}
    </svg>
  );
}

/** The free space counting up to a new figure, like numericText; jumps when it falls. */
function useCountUp(target: number, animate: boolean) {
  const [shown, setShown] = useState(target);
  const current = useRef(target);
  useEffect(() => {
    const from = current.current;
    if (!animate || target <= from) {
      current.current = target;
      setShown(target);
      return;
    }
    const start = performance.now();
    let frame = 0;
    const tick = (now: number) => {
      const progress = Math.min(1, (now - start) / 1400);
      const next = from + (target - from) * (1 - (1 - progress) ** 3);
      current.current = next;
      setShown(next);
      if (progress < 1) frame = requestAnimationFrame(tick);
    };
    frame = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(frame);
  }, [animate, target]);
  return shown;
}
