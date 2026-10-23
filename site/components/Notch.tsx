import type { ReactNode } from "react";
import { Wallpaper } from "./Wallpaper";

/** Apple's ease for things that grow out of the notch: quick out, long settle. */
export const notchEase = "cubic-bezier(0.32, 0.72, 0, 1)";

/**
 * The top of a Mac screen: wallpaper, a translucent menu bar, and whatever hangs from the
 * notch in the middle. Purely a stage, so it stays out of the accessibility tree.
 */
export function Screen({ tone, children, className = "" }: { tone: "blue" | "dusk" | "teal"; children: ReactNode; className?: string }) {
  return (
    <div className={`relative overflow-hidden ${className}`}>
      <Wallpaper tone={tone} />
      <div aria-hidden className="absolute inset-x-0 top-0 flex h-[34px] items-center justify-between bg-black/15 px-4 text-[13px] font-medium text-white/85 backdrop-blur-md">
        <span className="hidden gap-4 sm:flex">
          <span className="font-semibold">Finder</span>
          <span>Arquivo</span>
        </span>
        <span className="ml-auto tabular-nums">14:32</span>
      </div>
      <div className="relative flex h-full flex-col items-center">{children}</div>
    </div>
  );
}

/**
 * The closed notch: a black bar flush with the top of the screen, with the two shoulders
 * that curve it into the bezel. Its width follows what it's showing.
 */
export function ClosedNotch({ width, children }: { width: string; children: ReactNode }) {
  return (
    <div
      className="relative h-[34px] max-w-[94%] rounded-b-[14px] bg-black transition-[width] duration-500"
      style={{ width, transitionTimingFunction: notchEase }}
    >
      <Shoulders size={8} />
      {children}
    </div>
  );
}

/** The two concave corners where the notch meets the top edge. */
export function Shoulders({ size }: { size: number }) {
  const edge = `${size - 0.5}px`;
  return (
    <>
      <span aria-hidden className="absolute top-0" style={{ left: -size, width: size, height: size, background: `radial-gradient(circle at 0 100%, transparent ${edge}, #000 ${size}px)` }} />
      <span aria-hidden className="absolute top-0" style={{ right: -size, width: size, height: size, background: `radial-gradient(circle at 100% 100%, transparent ${edge}, #000 ${size}px)` }} />
    </>
  );
}

/**
 * One of several contents sharing the same spot: the visible one sharp, the others faded,
 * slightly shrunk and blurred, so a change cross-fades instead of popping.
 */
export function Swap({ shown, children, className = "" }: { shown: boolean; children: ReactNode; className?: string }) {
  return (
    <div
      aria-hidden={!shown}
      className={`absolute inset-0 transition-[opacity,scale,filter] duration-300 ${shown ? "scale-100 opacity-100 blur-none" : "pointer-events-none scale-[0.96] opacity-0 blur-[4px]"} ${className}`}
      style={{ transitionTimingFunction: "cubic-bezier(0.2, 0, 0, 1)" }}
    >
      {children}
    </div>
  );
}
