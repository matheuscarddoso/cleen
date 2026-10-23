"use client";

import { useEffect, useRef, useState } from "react";

/**
 * Steps through a scene's states on its own, but only while the scene is on screen, the
 * tab is visible and the person hasn't asked for reduced motion. With reduced motion the
 * scene rests on `still`, the state that tells the most in a single frame.
 */
export function useLoop<T extends HTMLElement>(durations: readonly number[], still = 0) {
  const ref = useRef<T>(null);
  const [index, setIndex] = useState(0);
  const [running, setRunning] = useState(false);
  const [reduced, setReduced] = useState(false);

  useEffect(() => {
    const element = ref.current;
    if (!element) return;
    const motion = window.matchMedia("(prefers-reduced-motion: reduce)");
    let visible = false;
    const update = () => {
      setReduced(motion.matches);
      setRunning(visible && !motion.matches && document.visibilityState === "visible");
    };
    const observer = new IntersectionObserver(([entry]) => {
      visible = entry?.isIntersecting ?? false;
      update();
    }, { threshold: 0.35 });
    observer.observe(element);
    motion.addEventListener("change", update);
    document.addEventListener("visibilitychange", update);
    if (motion.matches) setIndex(still);
    return () => {
      observer.disconnect();
      motion.removeEventListener("change", update);
      document.removeEventListener("visibilitychange", update);
    };
  }, [still]);

  useEffect(() => {
    if (!running || durations.length === 0) return;
    const timer = window.setTimeout(() => setIndex((current) => (current + 1) % durations.length), durations[index] ?? 3000);
    return () => window.clearTimeout(timer);
  }, [durations, index, running]);

  return { ref, index, setIndex, running, reduced };
}

/** Seconds counted while `counting`, back to `start` whenever `reset` turns on. */
export function useSeconds(counting: boolean, reset: boolean, start = 0) {
  const [seconds, setSeconds] = useState(start);
  useEffect(() => {
    if (reset) setSeconds(start);
  }, [reset, start]);
  useEffect(() => {
    if (!counting) return;
    const timer = window.setInterval(() => setSeconds((value) => value + 1), 1000);
    return () => window.clearInterval(timer);
  }, [counting]);
  return seconds;
}
