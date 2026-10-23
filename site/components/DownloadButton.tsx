import { site } from "@/lib/site";

export function DownloadButton({ size = "lg", label = "Baixar para Mac" }: { size?: "lg" | "sm"; label?: string }) {
  const sizing = size === "lg" ? "h-12 px-7 text-[17px]" : "h-8 px-4 text-[13px]";
  return (
    <a
      href={site.download}
      className={`inline-flex items-center gap-2 rounded-full bg-accent font-medium text-white transition-[background-color,transform] duration-200 hover:bg-[#0077ed] active:scale-[0.97] ${sizing}`}
    >
      <svg viewBox="0 0 20 20" aria-hidden className={size === "lg" ? "h-[18px] w-[18px]" : "h-[14px] w-[14px]"} fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round">
        <path d="M10 3v10m0 0-4-4m4 4 4-4M4 16.5h12" />
      </svg>
      {label}
    </a>
  );
}
