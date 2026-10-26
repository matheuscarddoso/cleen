import type { ReactNode } from "react";
import { Document } from "@/components/Document";
import { metadataFor } from "@/lib/meta";
import "../globals.css";

export const metadata = metadataFor("pt");
export { viewport } from "@/lib/meta";

export default function RootLayout({ children }: { children: ReactNode }) {
  return <Document lang="pt">{children}</Document>;
}
