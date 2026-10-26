import { pick, type Lang } from "@/lib/lang";
import { site } from "@/lib/site";

/** Apple's blue pill. */
export function DownloadButton({ lang, label, size = "md" }: { lang: Lang; label?: string; size?: "md" | "sm" }) {
  const l = pick(lang);
  // Apple's sizes: 8×16 at 17 pt, 4×11 at 12 pt in the bar.
  const sizing = size === "md" ? "px-4 py-2 text-[17px] leading-[1.18]" : "px-[11px] py-1 text-[12px] leading-[1.33]";
  return (
    <a
      href={site.download}
      className={`inline-flex items-center rounded-full bg-accent font-normal text-white transition-colors duration-200 ease-(--ease-apple) hover:bg-[#0077ed] ${sizing}`}
    >
      {label ?? l("Baixar", "Download")}
    </a>
  );
}

/** The outlined companion: "Saiba mais". */
export function OutlineLink({ href, children }: { href: string; children: string }) {
  return (
    <a
      href={href}
      className="inline-flex items-center rounded-full border border-accent px-[15px] py-[7px] text-[17px] leading-[1.18] text-accent transition-colors duration-200 ease-(--ease-apple) hover:bg-accent hover:text-white"
    >
      {children}
    </a>
  );
}

/** A plain blue link with Apple's chevron. */
export function MoreLink({ href, children }: { href: string; children: string }) {
  return (
    <a href={href} className="inline-flex items-center gap-1 text-[17px] text-link hover:underline">
      {children}
      <svg viewBox="0 0 10 16" aria-hidden className="h-[11px] w-[7px]" fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinecap="round" strokeLinejoin="round">
        <path d="m2 2 6 6-6 6" />
      </svg>
    </a>
  );
}
