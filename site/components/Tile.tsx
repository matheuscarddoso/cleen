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
      className={`flex h-full scroll-mt-20 flex-col overflow-hidden rounded-[18px] text-center ${dark ? "bg-black text-white" : "bg-tile text-ink"}`}
    >
      <div className="px-[8.33%] pt-7 sm:pt-11">
        <p className={`text-[21px] font-semibold leading-[1.19] tracking-[0.011em] ${dark ? "text-[#2997ff]" : "text-new"}`}>{eyebrow}</p>
        <h2 className="mx-auto mt-1 text-[clamp(28px,3vw,36px)] font-semibold leading-[1.05]">{title}</h2>
        <p className={`mx-auto mt-4 max-w-[420px] text-[17px] leading-[1.47] ${dark ? "text-white/70" : "text-mute"}`}>{children}</p>
        <div className="mt-4 flex flex-wrap items-center justify-center gap-x-4 gap-y-3.5 sm:mt-5">
          <DownloadButton />
          {more && <MoreLink href={more}>Saiba mais</MoreLink>}
        </div>
      </div>
      <div className="mt-auto w-full px-5 pb-5 pt-10 sm:px-10 sm:pb-10">{visual}</div>
    </article>
  );
}
