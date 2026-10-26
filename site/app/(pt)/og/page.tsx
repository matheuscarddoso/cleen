import type { Metadata } from "next";
import { ShareCard } from "@/components/ShareCard";

export const metadata: Metadata = { title: "Share card", robots: { index: false, follow: false } };

export default function Page() {
  return <ShareCard lang="pt" />;
}
