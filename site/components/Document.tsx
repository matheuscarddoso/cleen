import { Inter } from "next/font/google";
import type { ReactNode } from "react";
import { locale, type Lang } from "@/lib/lang";

// Macs draw SF Pro; everything else falls back to Inter.
const inter = Inter({ subsets: ["latin"], variable: "--font-inter", display: "swap" });

/** `<html>` and `<body>` for one language's root layout. */
export function Document({ lang, children }: { lang: Lang; children: ReactNode }) {
  return (
    <html lang={locale[lang]} className={inter.variable}>
      <body>{children}</body>
    </html>
  );
}
