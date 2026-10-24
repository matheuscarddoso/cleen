/**
 * TimerSession (Sources/CleenKit/Timer/TimerSession.swift) as plain values: a countdown
 * or Pomodoro's rounds, idle, running or paused. Time moves only through `tick`, one
 * second at a time, so the replica can play a script without a real clock. `clock` is
 * the replica's wall clock in seconds since midnight, for "termina às 14:57".
 */
export type TimerMode = "countdown" | "pomodoro";
export type TimerPhase = "countdown" | "focus" | "shortBreak" | "longBreak";

export type TimerSession = {
  mode: TimerMode;
  phase: TimerPhase;
  /** The Pomodoro round, 1-based. */
  round: number;
  /** The current phase's length in seconds, with minutes added while it runs. */
  duration: number;
  /** Seconds left; the whole duration while idle. */
  remaining: number;
  status: "idle" | "running" | "paused";
  /** The countdown length picked, in minutes; kept across modes and resets. */
  minutes: number;
  clock: number;
};

/** The one-tap lengths, in minutes. */
export const presets = [5, 10, 15, 25, 45, 60] as const;
export const minuteRange = { min: 1, max: 180 } as const;

/** 25 min focus, 5 min break, 15 min after the fourth round. */
export const plan = { focus: 25, shortBreak: 5, longBreak: 15, rounds: 4 } as const;

/** The menu bar's "qui 14:32". */
const startClock = 14 * 3600 + 32 * 60;

export function newSession(minutes = 10): TimerSession {
  return { mode: "countdown", phase: "countdown", round: 1, duration: minutes * 60, remaining: minutes * 60, status: "idle", minutes, clock: startClock };
}

export const isBreak = (phase: TimerPhase) => phase === "shortBreak" || phase === "longBreak";
export const isActive = (session: TimerSession) => session.status !== "idle";

function length(phase: TimerPhase, minutes: number): number {
  switch (phase) {
    case "countdown":
      return minutes * 60;
    case "focus":
      return plan.focus * 60;
    case "shortBreak":
      return plan.shortBreak * 60;
    case "longBreak":
      return plan.longBreak * 60;
  }
}

/** Start, pause or resume, whichever comes next. */
export function toggle(session: TimerSession): TimerSession {
  return { ...session, status: session.status === "running" ? "paused" : "running" };
}

/** Back to idle at the first phase, keeping the mode and the picked length. */
export function reset(session: TimerSession): TimerSession {
  const phase: TimerPhase = session.mode === "pomodoro" ? "focus" : "countdown";
  const duration = length(phase, session.minutes);
  return { ...session, phase, round: 1, duration, remaining: duration, status: "idle" };
}

/** One more minute on the clock. Idle, it lengthens the countdown about to start. */
export function addMinute(session: TimerSession): TimerSession {
  if (isActive(session)) return { ...session, duration: session.duration + 60, remaining: session.remaining + 60 };
  if (session.mode === "countdown") return setMinutes(session, session.minutes + 1);
  return session;
}

export function setMode(session: TimerSession, mode: TimerMode): TimerSession {
  return mode === session.mode ? session : reset({ ...session, mode });
}

/** Picks the countdown's length; ignored while one is under way. */
export function setMinutes(session: TimerSession, minutes: number): TimerSession {
  const clamped = Math.min(minuteRange.max, Math.max(minuteRange.min, Math.round(minutes)));
  if (session.mode === "countdown" && !isActive(session)) return { ...session, minutes: clamped, duration: clamped * 60, remaining: clamped * 60 };
  return { ...session, minutes: clamped };
}

/** Ends the phase: a countdown goes back to idle, Pomodoro moves on (and keeps going). */
export function finishPhase(session: TimerSession, autoStart = true): TimerSession {
  if (session.mode === "countdown") return reset(session);
  const last = session.round >= plan.rounds;
  const next =
    session.phase === "focus"
      ? { phase: (last ? "longBreak" : "shortBreak") as TimerPhase, round: session.round }
      : session.phase === "shortBreak"
        ? { phase: "focus" as TimerPhase, round: Math.min(session.round + 1, plan.rounds) }
        : { phase: "focus" as TimerPhase, round: 1 };
  const duration = length(next.phase, session.minutes);
  return { ...session, ...next, duration, remaining: duration, status: autoStart ? "running" : "idle" };
}

/** Skips to the next Pomodoro phase, carrying on running or idle. */
export function skip(session: TimerSession): TimerSession {
  return session.mode === "pomodoro" ? finishPhase(session, session.status === "running") : session;
}

/** One second of the wall clock; the countdown moves only while it runs. */
export function tick(session: TimerSession): TimerSession {
  if (session.status !== "running") return session;
  const next = { ...session, clock: session.clock + 1, remaining: session.remaining - 1 };
  return next.remaining <= 0 ? finishPhase(next) : next;
}

/** Share of the phase still left, 1 → 0: what the ring shows. */
export const remainingFraction = (session: TimerSession) => (session.duration > 0 ? session.remaining / session.duration : 0);

/** `25:00`, `0:07`, and `1:40:00` past 99 minutes (TimerClock.string). */
export function clockText(seconds: number): string {
  const total = Math.max(0, Math.ceil(seconds));
  const minutes = Math.floor(total / 60);
  const secs = String(total % 60).padStart(2, "0");
  if (minutes >= 100) return `${Math.floor(total / 3600)}:${String(minutes % 60).padStart(2, "0")}:${secs}`;
  return `${minutes}:${secs}`;
}

/** `25 min`, `1h`, `1h 30min` (TimerClock.length). */
export function lengthText(seconds: number): string {
  const minutes = Math.round(seconds / 60);
  if (minutes < 60) return `${minutes} min`;
  return minutes % 60 === 0 ? `${minutes / 60}h` : `${Math.floor(minutes / 60)}h ${minutes % 60}min`;
}

/** The wall-clock time the running phase ends, as "14:57". */
export function endText(session: TimerSession): string {
  const end = (session.clock + session.remaining) % 86400;
  return `${String(Math.floor(end / 3600)).padStart(2, "0")}:${String(Math.floor((end % 3600) / 60)).padStart(2, "0")}`;
}

/** "Timer", "Foco" or "Pausa". */
export function phaseTitle(phase: TimerPhase): string {
  return phase === "countdown" ? "Timer" : phase === "focus" ? "Foco" : "Pausa";
}

/** "Timer de 10 min", "Foco · rodada 2 de 4", "Pausa longa". */
export function phaseDetail(session: TimerSession): string {
  switch (session.phase) {
    case "countdown":
      return `Timer de ${lengthText(session.duration)}`;
    case "focus":
      return `Foco · rodada ${session.round} de ${plan.rounds}`;
    case "shortBreak":
      return `Pausa · rodada ${session.round} de ${plan.rounds}`;
    case "longBreak":
      return "Pausa longa";
  }
}
