import type { Metadata } from "next";
import { LegalPage } from "@/components/legal-page";
import { parseLegalText, readTermsOfUse } from "@/lib/legal";

// Kullanım koşulları (mağaza ve uygulama bağlantısı). Oturum istemez (proxy.ts PUBLIC_PATHS).
export const metadata: Metadata = { title: "Kullanım Koşulları · KampüsBet" };

export default async function TermsPage() {
  const text = await readTermsOfUse();
  return <LegalPage blocks={parseLegalText(text)} />;
}
