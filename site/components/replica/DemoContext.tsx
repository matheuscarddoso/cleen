"use client";

import { createContext, useContext, useEffect, useRef, useState } from "react";

export type Demo = {
  /** True while the demo should move on its own: on screen, tab visible, not paused. */
  playing: boolean;
  /** The person asked for reduced motion: show one telling state, don't animate. */
  reduced: boolean;
};

export const DemoContext = createContext<Demo>({ playing: false, reduced: false });

export function useDemo(): Demo {
  return useContext(DemoContext);
}

/**
 * Steps through a scripted demo while it plays; holds still otherwise. `still` is the
 * step shown with reduced motion. Returns the step and a setter for clicks.
 */
export function useSteps(durations: readonly number[], still = 0) {
  const { playing, reduced } = useDemo();
  const [step, setStep] = useState(0);
  useEffect(() => {
    if (reduced) setStep(still);
  }, [reduced, still]);
  useEffect(() => {
    if (!playing || durations.length === 0) return;
    const timer = window.setTimeout(() => setStep((current) => (current + 1) % durations.length), durations[step] ?? 2000);
    return () => window.clearTimeout(timer);
  }, [durations, playing, step]);
  return [step, setStep] as const;
}

/** Calls `tick` every `ms` while the demo plays. */
export function usePlayingInterval(tick: () => void, ms: number) {
  const { playing } = useDemo();
  const saved = useRef(tick);
  useEffect(() => {
    saved.current = tick;
  });
  useEffect(() => {
    if (!playing) return;
    const timer = window.setInterval(() => saved.current(), ms);
    return () => window.clearInterval(timer);
  }, [ms, playing]);
}

/**
 * Types `texts` one after another into a field, the way a person would: a letter at a
 * time, a pause on the finished word, then cleared for the next. Stops while paused.
 */
export function useTypewriter(texts: readonly string[], { speed = 110, hold = 1800 } = {}) {
  const { playing, reduced } = useDemo();
  const [state, setState] = useState({ index: 0, length: 0 });
  // Reduced motion is only known after mount: then rest on the first text, typed out.
  useEffect(() => {
    if (reduced) setState({ index: 0, length: texts[0]?.length ?? 0 });
  }, [reduced, texts]);
  useEffect(() => {
    if (!playing) return;
    const text = texts[state.index] ?? "";
    const done = state.length >= text.length;
    const timer = window.setTimeout(
      () => setState(done ? { index: (state.index + 1) % texts.length, length: 0 } : { index: state.index, length: state.length + 1 }),
      done ? hold : speed + Math.random() * 60,
    );
    return () => window.clearTimeout(timer);
  }, [hold, playing, speed, state, texts]);
  const full = texts[state.index] ?? "";
  return { text: full.slice(0, state.length), index: state.index, finished: state.length >= full.length };
}
