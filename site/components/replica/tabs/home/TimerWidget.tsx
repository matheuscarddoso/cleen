"use client";

import { useL } from "@/components/LangProvider";
import { notch } from "../../style";
import { ClockDigits, phaseTint, TimerRing } from "../timer/TimerRing";
import { clockText, isActive, phaseTitle, remainingFraction, type TimerPhase, type TimerSession } from "../timer/session";

/** The phase in English, as the app's strings file has it ("Foco" → "Focus", "Pausa" → "Break"). */
const phaseEnglish: Record<TimerPhase, string> = { countdown: "Timer", focus: "Focus", shortBreak: "Break", longBreak: "Break" };

/**
 * The small timer on Início (TimerWidget .small): the ring with the clock inside. A tap
 * starts or pauses it, or opens the Timer tab while nothing is going.
 */
export function TimerWidget({ session, still, onPress }: { session: TimerSession; still: boolean; onPress: () => void }) {
  const l = useL();
  const running = session.status === "running";
  const paused = session.status === "paused";
  const clock = clockText(session.remaining);
  const help = isActive(session) ? (running ? l("Pausar", "Pause") : l("Continuar", "Continue")) : l("Abrir o Timer", "Open Timer");
  const phase = l(phaseTitle(session.phase), phaseEnglish[session.phase]);
  return (
    <button type="button" onClick={onPress} title={help} aria-label={`${phase}, ${clock}. ${help}`} className="flex w-[88px] justify-center rounded-full">
      <TimerRing remaining={remainingFraction(session)} size={80} lineWidth={6} color={phaseTint(session.phase)} running={running} still={still}>
        <span className="flex flex-col items-center gap-0">
          <span className="text-[15px] font-semibold leading-[18px] transition-colors duration-300" style={{ color: paused ? notch.secondary : notch.primary }}>
            <ClockDigits text={clock} still={still} />
          </span>
          <span className="-mt-px text-[9.5px] font-medium leading-[11px]" style={{ color: notch.secondary }}>
            {paused ? l("pausado", "paused") : phase.toLowerCase()}
          </span>
        </span>
      </TimerRing>
    </button>
  );
}
