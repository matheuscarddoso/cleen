"use client";

import { Pause } from "lucide-react";
import { OpticalPlay } from "../OpticalPlay";
import { useEffect, useRef, useState, type ReactNode } from "react";
import { useDemo, useSteps } from "../DemoContext";
import { notch } from "../style";
import { DurationWheel } from "./timer/DurationWheel";
import { ClockDigits, PhaseGlyph, phaseTint, TimerRing, useTicker } from "./timer/TimerRing";
import {
  addMinute,
  clockText,
  endText,
  isActive,
  newSession,
  phaseDetail,
  plan,
  presets,
  remainingFraction,
  reset,
  setMinutes,
  setMode,
  skip,
  tick,
  toggle,
  type TimerSession,
} from "./timer/session";

type Control = "mode" | "chip" | "primary" | "reset" | "add" | "skip";

/**
 * The script, one action per step: 10 min idle, the 25 chip, Iniciar, Pausar, +1 min,
 * Continuar, Zerar, Pomodoro, Iniciar, Pular to the break, Zerar, back to Timer.
 */
const script: readonly { ms: number; press?: Control; run: (session: TimerSession) => TimerSession }[] = [
  { ms: 2200, press: "mode", run: () => newSession(10) },
  { ms: 1500, press: "chip", run: (session) => setMinutes(session, 25) },
  { ms: 4200, press: "primary", run: (session) => ({ ...session, status: "running" }) },
  { ms: 1800, press: "primary", run: (session) => ({ ...session, status: "paused" }) },
  { ms: 1500, press: "add", run: addMinute },
  { ms: 3200, press: "primary", run: (session) => ({ ...session, status: "running" }) },
  { ms: 1500, press: "reset", run: reset },
  { ms: 1800, press: "mode", run: (session) => setMode(session, "pomodoro") },
  { ms: 3200, press: "primary", run: (session) => ({ ...session, status: "running" }) },
  { ms: 3200, press: "skip", run: skip },
  { ms: 1400, press: "reset", run: reset },
];
const durations = script.map((step) => step.ms);

/** Reduced motion: a 25-minute timer paused part-way, the ring a quarter gone. */
const stillSession: TimerSession = { ...newSession(25), status: "paused", remaining: 18 * 60 + 42 };

/**
 * Timer, as NotchTimerTab lays it out: the countdown big on the left inside its ring,
 * a hairline, then the mode, the lengths and the controls. The script picks 25 min,
 * starts, pauses, adds a minute and runs a Pomodoro; any click hands it to the visitor.
 */
export function TimerTab() {
  const { playing, reduced } = useDemo();
  const [step] = useSteps(durations);
  const [scripted, setScripted] = useState<TimerSession>(() => newSession(10));
  const [manual, setManual] = useState<TimerSession | null>(null);
  const [pressed, setPressed] = useState<Control | null>(null);
  const applied = useRef<number | null>(null);

  // Each step's action runs once as the script reaches it, with a brief press on the
  // control it stands for.
  useEffect(() => {
    if (manual || reduced || applied.current === step) return;
    const first = applied.current === null;
    applied.current = step;
    const action = script[step];
    if (!action) return;
    setScripted((session) => action.run(session));
    if (first || !action.press) return;
    setPressed(action.press);
    const release = window.setTimeout(() => setPressed(null), 260);
    return () => window.clearTimeout(release);
  }, [manual, reduced, step]);

  const session = manual ?? (reduced ? stillSession : scripted);
  useTicker(playing && !manual && !reduced && scripted.status === "running", () => setScripted(tick));
  useTicker(manual?.status === "running", () => setManual((current) => (current ? tick(current) : current)));

  const act = (change: (session: TimerSession) => TimerSession) => {
    setPressed(null);
    setManual(change(session));
  };
  const active = isActive(session);
  const running = session.status === "running";
  const paused = session.status === "paused";
  const primaryTitle = running ? "Pausar" : paused ? "Continuar" : "Iniciar";
  const canReset = active || session.round !== 1 || session.phase !== (session.mode === "pomodoro" ? "focus" : "countdown");

  return (
    <div className="flex h-full items-center gap-5 px-1">
      <ClockFace session={session} still={reduced} onToggle={() => act(toggle)} />
      <div className="w-px self-stretch" style={{ background: notch.separator, marginBlock: 6 }} />
      <div className="flex min-w-0 flex-1 flex-col gap-2.5">
        <div className="flex items-center gap-2.5">
          <Segmented
            value={session.mode}
            disabled={active}
            pressed={pressed === "mode"}
            onChange={(mode) => act((current) => setMode(current, mode))}
          />
          <span className="flex-1" />
          <div
            className="flex items-center gap-[5px] transition-opacity duration-200"
            style={{ opacity: session.mode === "countdown" ? 1 : 0, visibility: session.mode === "countdown" ? "visible" : "hidden" }}
          >
            <DurationWheel
              minutes={session.minutes}
              highlighted={!(presets as readonly number[]).includes(session.minutes)}
              disabled={active}
              onChange={(minutes) => act((current) => setMinutes(current, minutes))}
            />
            <span className="text-[11px] font-medium" style={{ color: notch.tertiary }}>min</span>
          </div>
        </div>
        <div className="flex h-[26px] items-center">
          {session.mode === "countdown" ? (
            <div className="flex gap-0.5" role="group" aria-label="Durações">
              {presets.map((minutes) => (
                <Chip
                  key={minutes}
                  selected={session.minutes === minutes}
                  disabled={active}
                  pressed={pressed === "chip" && session.minutes === minutes}
                  label={`${minutes} minutos`}
                  onClick={() => act((current) => setMinutes(current, minutes))}
                >
                  {minutes}
                </Chip>
              ))}
            </div>
          ) : (
            <PomodoroPlan session={session} />
          )}
        </div>
        <div className="flex items-center gap-1.5">
          <Pill kind="primary" pressed={pressed === "primary"} title={`${primaryTitle} (espaço)`} onClick={() => act(toggle)}>
            <span className="flex min-w-[72px] items-center justify-center gap-[7px]">
              {running ? <Pause size={11} fill="currentColor" strokeWidth={0} aria-hidden /> : <OpticalPlay size={11} fill="currentColor" strokeWidth={1} strokeLinejoin="round" aria-hidden />}
              {primaryTitle}
            </span>
          </Pill>
          <Pill pressed={pressed === "reset"} disabled={!canReset} onClick={() => act(reset)}>Zerar</Pill>
          <Pill pressed={pressed === "add"} disabled={session.mode === "pomodoro" && !active} title="Mais um minuto" onClick={() => act(addMinute)}>
            +1 min
          </Pill>
          {session.mode === "pomodoro" && (
            <Pill pressed={pressed === "skip"} title={session.phase === "focus" ? "Pular para a pausa" : "Pular a pausa"} onClick={() => act(skip)}>
              Pular
            </Pill>
          )}
        </div>
      </div>
    </div>
  );
}

/** The ring with the phase glyph (play/pause on hover), and the countdown beside it. */
function ClockFace({ session, still, onToggle }: { session: TimerSession; still: boolean; onToggle: () => void }) {
  const [hovered, setHovered] = useState(false);
  const running = session.status === "running";
  const paused = session.status === "paused";
  const tint = phaseTint(session.phase);
  const status = running ? `termina às ${endText(session)}` : paused ? "pausado" : "pronto para começar";
  const clock = clockText(session.remaining);
  return (
    <div className="flex shrink-0 items-center gap-[18px]">
      <button
        type="button"
        onClick={onToggle}
        onPointerEnter={() => setHovered(true)}
        onPointerLeave={() => setHovered(false)}
        aria-label={running ? "Pausar" : "Iniciar"}
        className="rounded-full"
      >
        <TimerRing remaining={remainingFraction(session)} size={100} lineWidth={5} color={tint} running={running} still={still}>
          {hovered ? (
            running ? (
              <Pause size={22} fill="#fff" strokeWidth={0} aria-hidden />
            ) : (
              <OpticalPlay size={21} fill="#fff" strokeWidth={0} aria-hidden />
            )
          ) : (
            <span className="transition-opacity duration-300" style={{ opacity: 0.8 }}>
              <PhaseGlyph phase={session.phase} size={20} color={tint} />
            </span>
          )}
        </TimerRing>
      </button>
      <div className="flex flex-col gap-0.5 whitespace-nowrap" role="timer" aria-live="off">
        <span className="text-[11px] font-medium" style={{ color: notch.secondary }}>{phaseDetail(session)}</span>
        <span
          className="-ml-0.5 text-[44px] font-light leading-[1.05] tracking-[-0.01em] transition-colors duration-300"
          style={{ color: paused ? notch.secondary : notch.primary }}
        >
          <span className="sr-only">{clock}</span>
          <span aria-hidden>
            <ClockDigits text={clock} still={still} />
          </span>
        </span>
        <span className="text-[11px] tabular-nums" style={{ color: notch.tertiary }}>{status}</span>
      </div>
    </div>
  );
}

/** NotchSegmented: pill segments, white for the chosen one. */
function Segmented({ value, disabled, pressed, onChange }: { value: TimerSession["mode"]; disabled: boolean; pressed: boolean; onChange: (mode: TimerSession["mode"]) => void }) {
  const options = [
    { value: "countdown", label: "Timer" },
    { value: "pomodoro", label: "Pomodoro" },
  ] as const;
  return (
    <div
      role="radiogroup"
      aria-label="Modo"
      title={disabled ? "Zere o timer para trocar de modo" : "Timer simples ou Pomodoro"}
      className="flex shrink-0 gap-0.5 rounded-full p-0.5 transition-[opacity,scale] duration-150"
      style={{ background: notch.control, opacity: disabled ? 0.4 : 1, scale: pressed ? 0.97 : 1 }}
    >
      {options.map((option) => {
        const selected = option.value === value;
        return (
          <button
            key={option.value}
            type="button"
            role="radio"
            aria-checked={selected}
            disabled={disabled}
            onClick={() => onChange(option.value)}
            className="h-[22px] rounded-full px-[9px] text-[11px] font-medium transition-[background-color,color] duration-200"
            style={{ background: selected ? "#fff" : "transparent", color: selected ? "#000" : "rgba(255,255,255,0.75)" }}
          >
            {option.label}
          </button>
        );
      })}
    </div>
  );
}

/** TimerChip: a preset length as a pill, lifted when it's the length in use. */
function Chip({ selected, disabled, pressed, label, onClick, children }: { selected: boolean; disabled: boolean; pressed: boolean; label: string; onClick: () => void; children: ReactNode }) {
  return (
    <button
      type="button"
      aria-pressed={selected}
      aria-label={label}
      title={label}
      disabled={disabled}
      onClick={onClick}
      className="h-6 min-w-[34px] rounded-full px-2 text-[11.5px] font-medium tabular-nums transition-[background-color,color,opacity] duration-150 enabled:hover:bg-white/10"
      style={{
        background: selected ? notch.selection : pressed ? notch.control : undefined,
        color: selected ? notch.primary : notch.secondary,
        opacity: disabled ? 0.4 : 1,
      }}
    >
      {children}
    </button>
  );
}

/** Pomodoro's rhythm with the phase under way lifted, and the cycle's rounds. */
function PomodoroPlan({ session }: { session: TimerSession }) {
  const steps = [
    { title: "Foco", minutes: plan.focus, current: session.phase === "focus" },
    { title: "Pausa", minutes: plan.shortBreak, current: session.phase === "shortBreak" },
    { title: "Longa", minutes: plan.longBreak, current: session.phase === "longBreak" },
  ];
  const progress = session.phase === "focus" ? 1 - remainingFraction(session) : 1;
  return (
    <div className="flex items-center gap-0.5">
      {steps.map((step) => (
        <span
          key={step.title}
          className="flex h-6 items-center gap-1 rounded-full px-[9px] text-[11.5px] font-medium transition-[background-color,color] duration-200"
          style={{ background: step.current ? notch.selection : "transparent", color: step.current ? notch.primary : notch.secondary }}
        >
          {step.title}
          <span className="tabular-nums" style={{ color: step.current ? notch.secondary : notch.tertiary }}>{step.minutes}</span>
        </span>
      ))}
      <span className="flex gap-[3px] pl-2.5" role="img" aria-label={`Rodada ${session.round} de ${plan.rounds}`}>
        {Array.from({ length: plan.rounds }, (_, index) => {
          const round = index + 1;
          const fill = round < session.round ? 1 : round === session.round ? Math.max(0, Math.min(1, progress)) : 0;
          return (
            <span key={round} className="h-1 w-4 overflow-hidden rounded-full" style={{ background: notch.track }}>
              <span className="block h-full origin-left rounded-full transition-transform duration-1000 ease-linear" style={{ background: notch.barFill, transform: `scaleX(${fill})` }} />
            </span>
          );
        })}
      </span>
    </div>
  );
}

/** NotchPillButtonStyle: the white primary pill and the grey secondary one. */
function Pill({
  kind = "secondary",
  pressed,
  disabled = false,
  title,
  onClick,
  children,
}: {
  kind?: "primary" | "secondary";
  pressed: boolean;
  disabled?: boolean;
  title?: string;
  onClick: () => void;
  children: ReactNode;
}) {
  const primary = kind === "primary";
  return (
    <button
      type="button"
      title={title}
      disabled={disabled}
      onClick={onClick}
      className={`flex h-[26px] items-center whitespace-nowrap rounded-full px-3 text-[12px] font-medium transition-[background-color,opacity,scale] duration-150 active:scale-[0.97] ${
        primary ? "bg-white text-black enabled:hover:bg-white/90" : "bg-white/10 text-white enabled:hover:bg-white/[0.16]"
      }`}
      style={{ opacity: disabled ? 0.4 : 1, scale: pressed ? 0.97 : undefined, background: pressed ? (primary ? "rgba(255,255,255,0.8)" : notch.controlHover) : undefined }}
    >
      {children}
    </button>
  );
}
