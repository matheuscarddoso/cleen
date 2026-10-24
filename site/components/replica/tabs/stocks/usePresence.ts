"use client";

import { useEffect, useState } from "react";

type Gone = { key: string; index: number };

/**
 * The list as it should be drawn: `keys`, plus the ones just taken off, kept at their
 * old place for `ms` so they can fade out (SwiftUI's removal transition). The removal
 * is noticed during render, so a card never blinks out for a frame before it fades.
 */
export function usePresence(keys: readonly string[], ms: number): { key: string; leaving: boolean }[] {
  const signature = keys.join("|");
  const [state, setState] = useState<{ signature: string; keys: readonly string[]; gone: Gone[] }>({ signature, keys, gone: [] });

  if (state.signature !== signature) {
    const left = state.keys.flatMap((key, index) => (keys.includes(key) ? [] : [{ key, index }]));
    const kept = state.gone.filter((item) => !keys.includes(item.key) && !left.some((other) => other.key === item.key));
    setState({ signature, keys, gone: [...kept, ...left] });
  }

  const pending = state.gone.map((item) => item.key).join("|");
  useEffect(() => {
    if (!pending) return;
    const timer = window.setTimeout(() => {
      const done = pending.split("|");
      setState((current) => ({ ...current, gone: current.gone.filter((item) => !done.includes(item.key)) }));
    }, ms);
    return () => window.clearTimeout(timer);
  }, [ms, pending]);

  const drawn = keys.map((key) => ({ key, leaving: false }));
  for (const item of [...state.gone].sort((a, b) => a.index - b.index)) {
    if (keys.includes(item.key)) continue;
    drawn.splice(Math.min(item.index, drawn.length), 0, { key: item.key, leaving: true });
  }
  return drawn;
}
