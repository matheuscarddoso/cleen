"use client";

import { Pause, Play, SkipBack, SkipForward, type LucideIcon } from "lucide-react";
import type { Track } from "./data";

/**
 * NowPlayingCard: the artwork with the playing app's icon on its corner, title, album
 * and artist stacked beside it, and three small controls. A track change crossfades
 * the cover and slides the text in, like the card's smooth animation on identity.
 */
export function NowPlaying({
  track,
  playing,
  pressed,
  onPrevious,
  onToggle,
  onNext,
}: {
  track: Track;
  playing: boolean;
  /** The control the script is pressing, lit as if hovered. */
  pressed: "previous" | "toggle" | "next" | null;
  onPrevious: () => void;
  onToggle: () => void;
  onNext: () => void;
}) {
  return (
    <div className="flex items-center gap-3.5">
      <div className="relative size-[88px] shrink-0">
        <div className="absolute inset-0 overflow-hidden rounded-[22px]" style={{ background: "rgb(41,41,41)" }}>
          <div key={track.title} className="absolute inset-0 motion-safe:animate-[numeric_400ms_ease-out]" style={{ background: track.artwork }} />
          {/* A hairline so a dark cover still has an edge on the black panel. */}
          <div aria-hidden className="absolute inset-0 rounded-[22px] shadow-[inset_0_0_0_1px_rgba(255,255,255,0.1)]" />
        </div>
        <AppBadge />
      </div>
      <div className="flex min-w-0 flex-1 flex-col gap-0.5" key={track.title}>
        <span className="motion-safe:animate-[numeric_300ms_ease-out] truncate text-[15px] font-semibold leading-[18px]">{track.title}</span>
        <span className="truncate text-[14px] font-medium leading-[17px]" style={{ color: "rgba(255,255,255,0.62)" }}>{track.album}</span>
        <span className="truncate text-[14px] font-medium leading-[17px]" style={{ color: "rgba(255,255,255,0.45)" }}>{track.artist}</span>
        <div className="-ml-1.5 flex gap-1 pt-0.5">
          <PlayerButton icon={SkipBack} label="Anterior" lit={pressed === "previous"} onClick={onPrevious} />
          <PlayerButton icon={playing ? Pause : Play} label={playing ? "Pausar" : "Tocar"} lit={pressed === "toggle"} onClick={onToggle} />
          <PlayerButton icon={SkipForward} label="Próxima" lit={pressed === "next"} onClick={onNext} />
        </div>
      </div>
    </div>
  );
}

/** PlayerButton: a 15 pt filled glyph with a round hover. */
function PlayerButton({ icon: Icon, label, lit, onClick }: { icon: LucideIcon; label: string; lit: boolean; onClick: () => void }) {
  return (
    <button
      type="button"
      aria-label={label}
      title={label}
      onClick={onClick}
      className="flex size-[34px] items-center justify-center rounded-full transition-colors duration-150 hover:bg-white/[0.14]"
      style={{ background: lit ? "rgba(255,255,255,0.14)" : undefined }}
    >
      <Icon size={15} fill="currentColor" strokeWidth={1.6} strokeLinejoin="round" aria-hidden />
    </button>
  );
}

/** The playing app's icon on the artwork's corner: Spotify's, its mark on the dark squircle. */
function AppBadge() {
  return (
    <span
      aria-hidden
      className="absolute -bottom-[7px] -right-[7px] flex size-[30px] items-center justify-center rounded-[7px] shadow-[0_2px_4px_rgba(0,0,0,0.4),inset_0_0_0_1px_rgba(255,255,255,0.1)]"
      style={{ background: "#121212" }}
    >
      <svg viewBox="0 0 24 24" className="size-[20px]" fill="#1ed760">
        <path d="M12 0C5.4 0 0 5.4 0 12s5.4 12 12 12 12-5.4 12-12S18.66 0 12 0zm5.521 17.34c-.24.359-.66.48-1.021.24-2.82-1.74-6.36-2.101-10.561-1.141-.418.122-.779-.179-.899-.539-.12-.421.18-.78.54-.9 4.56-1.021 8.52-.6 11.64 1.32.42.18.479.659.301 1.02zm1.44-3.3c-.301.42-.841.6-1.262.3-3.239-1.98-8.159-2.58-11.939-1.38-.479.12-1.02-.12-1.14-.6-.12-.48.12-1.021.6-1.141C9.6 9.9 15 10.561 18.72 12.84c.361.181.54.78.241 1.2zm.12-3.36C15.24 8.4 8.82 8.16 5.16 9.301c-.6.179-1.2-.181-1.38-.721-.18-.601.18-1.2.72-1.381 4.26-1.26 11.28-1.02 15.721 1.621.539.3.719 1.02.419 1.56-.299.421-1.02.599-1.559.3z" />
      </svg>
    </span>
  );
}
