"use client";

import { useEffect, useRef, useState } from "react";

/**
 * Glides a number to `target` over `ms` (ease in-out), the way a finger drags a slider,
 * so the figure beside it counts through the values. Off, it follows `target` at once.
 */
export function useGlide(target: number, on: boolean, ms = 750): number {
  const [value, setValue] = useState(target);
  const current = useRef(target);

  useEffect(() => {
    if (!on) {
      current.current = target;
      setValue(target);
      return;
    }
    const from = current.current;
    if (from === target) return;
    const start = performance.now();
    let frame = 0;
    const tick = (now: number) => {
      const t = Math.min(1, (now - start) / ms);
      const eased = t < 0.5 ? 2 * t * t : 1 - (-2 * t + 2) ** 2 / 2;
      current.current = from + (target - from) * eased;
      setValue(current.current);
      if (t < 1) frame = requestAnimationFrame(tick);
    };
    frame = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(frame);
  }, [ms, on, target]);

  return on ? value : target;
}
