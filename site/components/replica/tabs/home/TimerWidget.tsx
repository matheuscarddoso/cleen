"use client";

import { notch } from "../../style";
import { ClockDigits, phaseTint, TimerRing } from "../timer/TimerRing";
import { clockText, isActive, phaseTitle, remainingFraction, type TimerSession } from "../timer/session";

/**
 * The small timer on Início (TimerWidget .small): the ring with the clock inside. A tap
 * starts or pauses it, or opens the Timer tab while nothing is going.
 */
export function TimerWidget({ session, still, onPress }: { session: TimerSession; still: boolean; onPress: () => void }) {
  const running = session.status === "running";
  const paused = session.status === "paused";
  const clock = clockText(session.remaining);
  const help = isActive(session) ? (running ? "Pausar" : "Continuar") : "Abrir o Timer";
  return (
    <button type="button" onClick={onPress} title={help} aria-label={`${phaseTitle(session.phase)}, ${clock}. ${help}`} className="flex w-[88px] justify-center rounded-full">
      <TimerRing remaining={remainingFraction(session)} size={80} lineWidth={6} color={phaseTint(session.phase)} running={running} still={still}>
        <span className="flex flex-col items-center gap-0">
          <span className="text-[15px] font-semibold leading-[18px] transition-colors duration-300" style={{ color: paused ? notch.secondary : notch.primary }}>
            <ClockDigits text={clock} still={still} />
          </span>
          <span className="-mt-px text-[9.5px] font-medium leading-[11px]" style={{ color: notch.secondary }}>
            {paused ? "pausado" : phaseTitle(session.phase).toLowerCase()}
          </span>
        </span>
      </TimerRing>
    </button>
  );
}
