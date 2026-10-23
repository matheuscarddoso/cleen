import type { ReactNode } from "react";
import { DownloadButton, MoreLink } from "./Buttons";

/**
 * One of Apple's product tiles: eyebrow, a two-line headline, a sentence, the two calls
 * to action, and the product picture filling the bottom. `dark` flips it to black.
 */
export function Tile({
  id,
  eyebrow,
  title,
  children,
  more,
  visual,
  dark = false,
}: {
  id?: string;
  eyebrow: string;
  title: ReactNode;
  children: ReactNode;
  more?: string;
  visual: ReactNode;
  dark?: boolean;
}) {
  return (
    <article
      id={id}
      className={`flex scroll-mt-20 flex-col overflow-hidden rounded-[28px] text-center ${dark ? "bg-black text-white" : "bg-tile text-ink"}`}
    >
      <div className="px-8 pt-12 sm:px-12">
        <p className={`text-[17px] font-semibold ${dark ? "text-[#2997ff]" : "text-claude"}`}>{eyebrow}</p>
        <h2 className="mx-auto mt-1 text-[clamp(28px,3.4vw,40px)] font-semibold leading-[1.1] tracking-[-0.02em]">{title}</h2>
        <p className={`mx-auto mt-4 max-w-[420px] text-[17px] leading-[1.47] ${dark ? "text-white/70" : "text-mute"}`}>{children}</p>
        <div className="mt-6 flex flex-wrap items-center justify-center gap-5">
          <DownloadButton />
          {more && <MoreLink href={more}>Saiba mais</MoreLink>}
        </div>
      </div>
      <div className="mt-10 flex flex-1 items-end px-6 sm:px-10">
        <div className="w-full">{visual}</div>
      </div>
    </article>
  );
}
