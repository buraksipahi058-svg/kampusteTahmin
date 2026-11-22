import type { Metadata } from "next";
import { LegalPage } from "@/components/legal-page";
import { parseLegalText, readPrivacyNotice } from "@/lib/legal";

// Mağazadaki "gizlilik politikası" bağlantısı. Oturum istemez (proxy.ts PUBLIC_PATHS).
export const metadata: Metadata = { title: "KVKK Aydınlatma Metni · KampüsBet" };

export default async function PrivacyPage() {
  const text = await readPrivacyNotice();
  return <LegalPage blocks={parseLegalText(text)} />;
}
