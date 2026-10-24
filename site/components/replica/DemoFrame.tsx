"use client";

import { Pause, Play } from "lucide-react";
import { useEffect, useRef, useState, type ReactNode } from "react";
import { Wallpaper } from "../Wallpaper";
import { DemoContext } from "./DemoContext";

/** The stage the panel hangs in, in design pixels; the frame scales it to fit. */
export const canvas = { width: 760, height: 396 } as const;

/**
 * Apple's media frame for a demo: the top of a Mac screen (wallpaper, menu bar) with the
 * replica hanging from the notch, scaled to the frame's width, and the round play/pause
 * control in the corner. It plays only on screen, with the tab visible and never with
 * reduced motion; clicking or typing into the replica hands it to the visitor.
 */
export function DemoFrame({
  label,
  tone = "blue",
  control = "sm",
  children,
}: {
  label: string;
  tone?: "blue" | "dusk" | "teal";
  control?: "sm" | "lg";
  children: ReactNode;
}) {
  const box = useRef<HTMLDivElement>(null);
  const [width, setWidth] = useState<number | null>(null);
  const [visible, setVisible] = useState(false);
  const [reduced, setReduced] = useState(false);
  const [pageShown, setPageShown] = useState(true);
  const [paused, setPaused] = useState(false);

  useEffect(() => {
    const element = box.current;
    if (!element) return;
    const resize = new ResizeObserver(([entry]) => entry && setWidth(entry.contentRect.width));
    const view = new IntersectionObserver(([entry]) => setVisible(entry?.isIntersecting ?? false), { threshold: 0.35 });
    const motion = window.matchMedia("(prefers-reduced-motion: reduce)");
    const updateMotion = () => setReduced(motion.matches);
    const updatePage = () => setPageShown(document.visibilityState === "visible");
    resize.observe(element);
    view.observe(element);
    updateMotion();
    motion.addEventListener("change", updateMotion);
    document.addEventListener("visibilitychange", updatePage);
    return () => {
      resize.disconnect();
      view.disconnect();
      motion.removeEventListener("change", updateMotion);
      document.removeEventListener("visibilitychange", updatePage);
    };
  }, []);

  const playing = visible && pageShown && !reduced && !paused;
  // On a phone the whole stage would make the panel's text unreadable: zoom into the
  // panel instead, letting the wallpaper either side go.
  const focus = width !== null && width < 480 ? 700 : canvas.width;
  const scale = width === null ? 1 : width / focus;
  const offset = width === null ? 0 : (width - canvas.width * scale) / 2;
  const button = control === "lg" ? { box: 36, icon: 16, inset: 16 } : { box: 28, icon: 13, inset: 8 };

  return (
    <div
      ref={box}
      role="group"
      aria-roledescription="demonstração interativa"
      aria-label={label}
      className="relative w-full overflow-hidden"
      style={{ aspectRatio: "1280 / 666", borderRadius: width === null ? 8 : width * 0.01875 }}
    >
      <Wallpaper tone={tone} />
      <div
        className="absolute left-0 top-0 origin-top-left"
        style={{ width: canvas.width, height: canvas.height, transform: `translateX(${offset}px) scale(${scale})` }}
        onPointerDown={() => setPaused(true)}
        onKeyDown={() => setPaused(true)}
      >
        <MenuBar />
        <DemoContext.Provider value={{ playing, reduced }}>
          <div className="absolute left-1/2 top-0 -translate-x-1/2">{children}</div>
        </DemoContext.Provider>
      </div>
      {!reduced && (
        <button
          type="button"
          onClick={() => setPaused((value) => !value)}
          aria-label={paused ? "Reproduzir demonstração" : "Pausar demonstração"}
          className="absolute z-10 flex items-center justify-center rounded-full bg-[rgba(210,210,215,0.64)] text-black/55 backdrop-blur-[20px] backdrop-saturate-[1.8] transition-[background-color,color,scale] duration-200 hover:bg-[rgba(223,223,227,0.7)] hover:text-black/65 active:scale-[0.96]"
          style={{ width: button.box, height: button.box, right: button.inset, bottom: button.inset }}
        >
          {paused ? <Play size={button.icon} fill="currentColor" strokeWidth={0} className="translate-x-[1px]" /> : <Pause size={button.icon} fill="currentColor" strokeWidth={0} />}
        </button>
      )}
    </div>
  );
}

/** The menu bar behind the panel; at this crop only the clock shows past its shoulders. */
function MenuBar() {
  return (
    <div aria-hidden className="absolute inset-x-0 top-0 flex h-8 items-center justify-between bg-black/20 px-3.5 text-[13px] font-medium text-white/90 backdrop-blur-md">
      <span />
      <span className="tabular-nums">14:32</span>
    </div>
  );
}
