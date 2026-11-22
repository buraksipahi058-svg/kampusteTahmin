import type { Metadata } from "next";
import Link from "next/link";
import { LegalPage } from "@/components/legal-page";
import { parseLegalText } from "@/lib/legal";

// Mağazadaki "hesap silme" bağlantısı (Google Play veri silme şartı). Oturum istemez (proxy.ts PUBLIC_PATHS).
// Ne silinip ne kaldığı KVKK metninin 6. bölümüyle ve `delete_my_account` ile aynı olmalı.
export const metadata: Metadata = { title: "Hesap silme · KampüsBet" };

const TEXT = `# KampüsBet hesabını silme

## Uygulamadan (önerilen)

- KampüsBet uygulamasını aç ve giriş yap.
- Profil sekmesinde en alta in, "Hesabımı sil"e dokun.
- Açılan pencerede "Anladım, hesabım silinsin" kutusunu işaretleyip "Hesabı sil"e dokun.

Sonuçlanmamış bahsin, düellon ya da hakemliğin varken hesap silinemez; bunlar birkaç gün içinde sonuçlanır.

## Uygulamaya giremiyorsan

Hesabının e-posta adresinden [iletişim e-postası] adresine "Hesabımı silin" konulu bir e-posta gönder. Talebin en geç 30 gün içinde sonuçlandırılır.

## Neler silinir, neler kalır

- Silinir: adın, soyadın, bölümün, okul e-postan, giriş e-postan, şifren, oturumların, verilen izinler ve sıralama satırların. Profilin okul arkadaşlarına "Silinmiş Kullanıcı" olarak görünür.
- Kimliğinle bağı koparılarak saklanır: sanal puan (SP / SSP) hareketleri, bahis ve sonuç kayıtları, XP ve market alımları; diğer kullanıcıların bahis sonuçları ve sistemin bütünlüğü bu kayıtlara dayanır.
- Altyapı sağlayıcısının güvenlik kayıtları sağlayıcının saklama süresi boyunca tutulabilir.`;

export default function AccountDeletionPage() {
  return (
    <LegalPage blocks={parseLegalText(TEXT)}>
      <p className="mt-4">
        Ayrıntılar:{" "}
        <Link href="/gizlilik" className="underline">
          KVKK Aydınlatma Metni
        </Link>
      </p>
    </LegalPage>
  );
}
