"use client";

import { useCallback, useEffect, useRef, useState, type ReactNode } from "react";

/**
 * Apple's horizontal gallery: cards that snap as they scroll, and two round paddles
 * under them that page by one card and dim at either end.
 */
export function Gallery({ children, label }: { children: ReactNode; label: string }) {
  const track = useRef<HTMLDivElement>(null);
  const [edges, setEdges] = useState({ start: true, end: false });

  const measure = useCallback(() => {
    const element = track.current;
    if (!element) return;
    setEdges({
      start: element.scrollLeft <= 4,
      end: element.scrollLeft + element.clientWidth >= element.scrollWidth - 4,
    });
  }, []);

  useEffect(() => {
    const element = track.current;
    if (!element) return;
    measure();
    element.addEventListener("scroll", measure, { passive: true });
    window.addEventListener("resize", measure);
    return () => {
      element.removeEventListener("scroll", measure);
      window.removeEventListener("resize", measure);
    };
  }, [measure]);

  const page = (direction: 1 | -1) => {
    const element = track.current;
    const card = element?.firstElementChild as HTMLElement | null;
    if (!element || !card) return;
    element.scrollBy({ left: direction * (card.offsetWidth + 20), behavior: "smooth" });
  };

  return (
    <div>
      <div ref={track} role="region" aria-label={label} className="no-scrollbar flex snap-x snap-mandatory gap-5 overflow-x-auto overscroll-x-contain pb-1">
        {children}
      </div>
      <div className="mt-4 flex justify-center gap-1.5">
        <Paddle direction="previous" disabled={edges.start} onClick={() => page(-1)} />
        <Paddle direction="next" disabled={edges.end} onClick={() => page(1)} />
      </div>
    </div>
  );
}

function Paddle({ direction, disabled, onClick }: { direction: "previous" | "next"; disabled: boolean; onClick: () => void }) {
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled}
      aria-label={direction === "previous" ? "Anterior" : "Próxima"}
      className="group relative flex h-11 w-11 items-center justify-center text-ink disabled:cursor-default disabled:text-faint"
    >
      <span aria-hidden className="absolute h-[30px] w-[30px] rounded-full shadow-[inset_0_0_0_2px_currentColor] transition-colors duration-150 group-enabled:group-hover:bg-ink" />
      <svg viewBox="0 0 11 11" aria-hidden className="relative h-[11px] w-[11px] transition-colors duration-150 group-enabled:group-hover:text-white" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
        {direction === "previous" ? <path d="M7 1.5 3 5.5l4 4" /> : <path d="m4 1.5 4 4-4 4" />}
      </svg>
    </button>
  );
}
