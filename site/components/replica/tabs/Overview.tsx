"use client";

import { ChevronRight, CircleCheck, CodeXml, File, FileText, Hammer, Package, Puzzle, Trash2, type LucideIcon } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { useL } from "@/components/LangProvider";
import { pick, type Lang } from "@/lib/lang";
import { useDemo, useSteps } from "../DemoContext";
import { useReplica } from "../ReplicaContext";
import { reviewTitle, type Review, type ReviewItem } from "../review";
import { level, notch } from "../style";
import { bytes, cleaned, cleanSize, findings, formatPercent, rescanned, usedFraction, type Disk } from "./overview/disk";

/** Idle, the press, the scans landing one by one, Limpar, the review, cleaning, the space back. */
const script = [2000, 220, 800, 650, 650, 2400, 220, 3200, 1700, 4400] as const;
const steps = { review: 7, cleaning: 8 } as const;

const idle: Disk = { phase: "idle", scanned: false, found: 0, armed: false, pressed: false, report: null, data: findings };

/** The script's state at each step; step 5 (results in, "Limpar 1,28 GB") is the still. */
function scripted(step: number): Disk {
  if (step <= 1) return { ...idle, pressed: step === 1 };
  if (step <= 4) return { ...idle, phase: "scanning", found: step - 2 };
  const ready: Disk = { ...idle, phase: "ready", scanned: true, found: 3 };
  if (step <= steps.review) return { ...ready, pressed: step === 6 };
  if (step === steps.cleaning) return { ...ready, phase: "cleaning" };
  return { ...ready, report: cleanSize(findings), data: cleaned(findings) };
}

/** What "Limpar" lists before it deletes: Lixo's safe caches and the idle projects' folders. */
function reviewItems(data: Disk["data"], lang: Lang): ReviewItem[] {
  const l = pick(lang);
  const items: ReviewItem[] = [];
  if (data.junkSafe > 0) {
    const xcode = Math.round(data.junkSafe * 0.59);
    const apps = Math.round(data.junkSafe * 0.343);
    items.push({ name: l("Caches do Xcode", "Xcode caches"), detail: l("DerivedData, que o Xcode recria", "DerivedData, which Xcode rebuilds"), size: xcode, icon: Hammer });
    items.push({ name: l("Caches de apps", "App caches"), detail: "~/Library/Caches", size: apps, icon: Package });
    items.push({ name: l("Logs antigos", "Old logs"), detail: l("Mais de 30 dias", "Older than 30 days"), size: data.junkSafe - xcode - apps, icon: FileText });
  }
  if (data.projectsSafe > 0) items.push({ name: "node_modules", detail: l("~/Projetos/site-antigo", "~/Projects/old-site"), size: data.projectsSafe, icon: CodeXml });
  return items;
}

/**
 * Visão geral, as NotchOverviewTab lays it out: free space as one large light figure
 * with the one action under it, a hairline, then what can be cleaned. The script scans,
 * shows the review of what goes, cleans, and the free space counts up; every button works.
 */
export function OverviewTab() {
  const l = useL();
  const { lang } = l;
  const { reduced } = useDemo();
  const [step] = useSteps(script, 5);
  const { review, setReview } = useReplica();
  const [manual, setManual] = useState<Disk | null>(null);
  const scriptedReview = useRef<Review | null>(null);
  const timers = useRef<number[]>([]);
  const disk = manual ?? scripted(step);
  const { data } = disk;

  useEffect(() => () => timers.current.forEach((timer) => window.clearTimeout(timer)), []);

  // The script's review: up on its step, gone (as if confirmed) on the next. The visitor
  // taking over drops it.
  useEffect(() => {
    if (manual === null && step === steps.review) {
      if (scriptedReview.current) return;
      const items = reviewItems(findings, lang);
      const shown: Review = { title: reviewTitle(items.length, "delete", lang), outcome: "delete", items, onConfirm: () => {} };
      scriptedReview.current = shown;
      setReview(shown);
    } else if (scriptedReview.current) {
      if (review === scriptedReview.current) setReview(null);
      scriptedReview.current = null;
    }
  }, [lang, manual, review, setReview, step]);

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

  // ConfirmingButton: the notch grows and lists what goes; Confirmar cleans.
  const clean = () => {
    clearTimers();
    const from = { ...disk, armed: false, pressed: false };
    setManual(from);
    const items = reviewItems(from.data, lang);
    setReview({
      title: reviewTitle(items.length, "delete", lang),
      outcome: "delete",
      items,
      onConfirm: () => {
        setManual({ ...from, phase: "cleaning" });
        later(1700, (current) => ({ ...current, phase: "ready", report: cleanSize(current.data), data: cleaned(current.data) }));
      },
    });
  };

  const free = useCountUp(data.free, !reduced);
  const used = usedFraction(data);
  const busy = disk.phase === "scanning" || disk.phase === "cleaning";
  const value = (index: number, size: number) => (disk.phase === "scanning" ? (disk.found > index ? bytes(size, lang) : "…") : disk.scanned ? bytes(size, lang) : "—");

  return (
    <div className="flex h-full items-start gap-[18px] pt-1">
      <div className="flex w-[240px] shrink-0 flex-col gap-1.5 pl-1">
        <span className="text-[12px] font-medium leading-[14px]" style={{ color: notch.secondary }}>{l("Disco", "Disk")}</span>
        <span className="text-[34px] font-light leading-[41px] tabular-nums" aria-label={l(`${bytes(data.free, lang)} livres`, `${bytes(data.free, lang)} free`)}>{bytes(free, lang)}</span>
        <span className="text-[11px] leading-[13px] tabular-nums" style={{ color: notch.secondary }}>
          {l(
            `livres de ${bytes(data.total, lang)} · ${formatPercent(used, lang)} em uso`,
            `free of ${bytes(data.total, lang)} · ${formatPercent(used, lang)} in use`,
          )}
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
              {disk.phase === "scanning" ? l("Analisando…", "Scanning…") : l("Limpando…", "Cleaning…")}
            </span>
          ) : disk.scanned && cleanSize(data) > 0 ? (
            <Pill kind="primary" pressed={disk.pressed} onClick={clean}>
              {l(`Limpar ${bytes(cleanSize(data), lang)}`, `Clean ${bytes(cleanSize(data), lang)}`)}
            </Pill>
          ) : (
            <Pill kind="primary" pressed={disk.pressed} onClick={scan}>
              {disk.scanned ? l("Analisar de novo", "Scan Again") : l("Analisar o Mac", "Scan the Mac")}
            </Pill>
          )}
        </div>
        {disk.report !== null && !busy && (
          <p className="flex animate-[numeric_300ms_ease-out] items-center gap-1.5 text-[12px] font-medium leading-[14px] tabular-nums">
            <CircleCheck size={13} strokeWidth={2.4} style={{ color: notch.good }} aria-hidden />
            {l(`${bytes(disk.report, lang)} liberados`, `${bytes(disk.report, lang)} freed`)}
          </p>
        )}
      </div>
      <div className="w-px self-stretch" style={{ background: notch.separator }} />
      <div
        className="min-w-0 flex-1 overflow-hidden rounded-[12px]"
        style={{ background: notch.card, boxShadow: `inset 0 0 0 1px ${notch.cardStroke}` }}
      >
        <MeterRow icon={Trash2} label={l("Lixo", "Trash")} value={value(0, data.junk)} />
        <Hairline />
        <MeterRow icon={CodeXml} label={l("Projetos parados", "Idle projects")} value={value(2, data.projects)} />
        <Hairline />
        <MeterRow icon={Puzzle} label={l("Restos de apps", "App Leftovers")} value={value(1, data.orphans)} />
        <Hairline />
        {/* Not part of the smart scan: it stays a dash until its own tab looks. */}
        <MeterRow icon={File} label={l("Arquivos grandes", "Large Files")} value="—" />
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
