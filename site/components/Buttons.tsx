import { site } from "@/lib/site";

/** Apple's blue pill. */
export function DownloadButton({ label = "Baixar", size = "md" }: { label?: string; size?: "md" | "sm" }) {
  const sizing = size === "md" ? "h-11 px-[22px] text-[17px]" : "h-7 px-3 text-[12px]";
  return (
    <a
      href={site.download}
      className={`inline-flex items-center rounded-full bg-accent font-normal text-white transition-colors duration-200 hover:bg-[#0077ed] ${sizing}`}
    >
      {label}
    </a>
  );
}

/** The outlined companion: "Saiba mais". */
export function OutlineLink({ href, children }: { href: string; children: string }) {
  return (
    <a
      href={href}
      className="inline-flex h-11 items-center rounded-full border border-accent px-[22px] text-[17px] text-accent transition-colors duration-200 hover:bg-accent hover:text-white"
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
