import type { Metadata, Viewport } from "next";
import { Inter } from "next/font/google";
import type { ReactNode } from "react";
import { site } from "@/lib/site";
import "./globals.css";

// Macs draw SF Pro; everything else falls back to Inter.
const inter = Inter({ subsets: ["latin"], variable: "--font-inter", display: "swap" });

const description =
  "O Cleen mora no notch do seu Mac: limpa o disco, move janelas, cola emoji, mostra o Claude Code trabalhando e traz mais de vinte ferramentas a um gesto. Grátis.";

export const metadata: Metadata = {
  metadataBase: new URL(site.url),
  title: { default: "Cleen — Tudo no notch.", template: "%s · Cleen" },
  description,
  applicationName: site.name,
  authors: [{ name: site.author, url: site.authorUrl }],
  alternates: { canonical: "/" },
  icons: { icon: "/favicon.png", apple: "/apple-touch-icon.png" },
  openGraph: {
    type: "website",
    url: site.url,
    siteName: site.name,
    title: "Cleen — Tudo no notch.",
    description,
    locale: "pt_BR",
    images: [{ url: "/og.png", width: 1200, height: 630, alt: "O painel do Cleen aberto no notch de um Mac" }],
  },
  twitter: { card: "summary_large_image", title: "Cleen — Tudo no notch.", description, images: ["/og.png"] },
};

export const viewport: Viewport = { themeColor: "#f5f5f7", colorScheme: "light" };

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="pt-BR" className={inter.variable}>
      <body>{children}</body>
    </html>
  );
}
