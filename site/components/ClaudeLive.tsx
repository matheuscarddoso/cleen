"use client";

import Image from "next/image";
import { Check } from "./Icons";
import { ClosedNotch, Screen, Swap, notchEase } from "./Notch";
import { useLoop, useSeconds } from "./useLoop";

/** Working, asking, approved, working again, done. */
const durations = [2600, 2000, 900, 2400, 2800] as const;
const steps = { run: 0, ask: 1, approve: 2, resume: 3, done: 4 } as const;

/**
 * A Claude Code session as the notch shows it: the asterisk turning while it works, the
 * permission card when it needs you, the green check when it's finished.
 */
export function ClaudeLive() {
  const { ref, index, running } = useLoop<HTMLDivElement>(durations, steps.ask);
  const seconds = useSeconds(running && index !== steps.done, index === steps.run, 3);
  const asking = index === steps.ask || index === steps.approve;
  const done = index === steps.done;
  const label = index === steps.run ? "Rodando Bash" : asking ? "Esperando você" : "Rodando testes";

  return (
    <div ref={ref}>
      <Screen tone="dusk" className="h-[280px] rounded-t-[18px] sm:h-[300px]">
        <ClosedNotch width={done ? "340px" : "330px"}>
          <Swap shown={!done} className="flex items-center justify-between px-4 text-[14px] font-medium text-white">
            <span className="flex items-center gap-2">
              <span className="claude-glyph w-4 text-center text-[16px] leading-none text-claude" aria-hidden />
              {label}
            </span>
            <span className="tabular-nums text-white/70">{seconds} s</span>
          </Swap>
          <Swap shown={done} className="flex items-center justify-between px-4 text-[14px] font-medium text-white">
            <span className="flex items-center gap-2">
              <span className="flex h-4 w-4 items-center justify-center rounded-full bg-[#30d158]">
                <Check className="h-2.5 w-2.5 text-white" strokeWidth={3.5} />
              </span>
              Pronto
            </span>
            <span className="text-white/70">Refatorar o checkout</span>
          </Swap>
        </ClosedNotch>

        <div
          aria-hidden={!asking}
          className={`mt-6 w-[min(360px,90%)] origin-top rounded-[18px] bg-black/85 p-4 text-left text-white shadow-[0_20px_50px_rgba(0,0,0,0.45)] ring-1 ring-white/10 backdrop-blur-xl transition-[opacity,translate,scale] duration-500 ${asking ? "translate-y-0 scale-100 opacity-100" : "-translate-y-3 scale-[0.96] opacity-0"}`}
          style={{ transitionTimingFunction: notchEase }}
        >
          <p className="flex items-center gap-2 text-[13px] font-medium">
            <Image src="/claude.svg" alt="" width={14} height={14} />
            Refatorar o checkout
          </p>
          <p className="mt-0.5 text-[12px] text-white/55">Quer rodar um comando</p>
          <p className="mt-3 rounded-[10px] bg-white/[0.07] px-3 py-2 font-mono text-[12px] text-white/85">$ npm run test</p>
          <div className="mt-3 flex justify-end gap-2 text-[12px] font-medium">
            <span className="rounded-full bg-white/10 px-3 py-1">Negar</span>
            <span
              className={`rounded-full px-3 py-1 text-black transition-[scale,background-color] duration-150 ${index === steps.approve ? "scale-[0.96] bg-white/80" : "bg-white"}`}
            >
              Permitir ⏎
            </span>
          </div>
        </div>
      </Screen>
    </div>
  );
}
