# Bölge: Güvenlik, hesap silme, KVKK

Adım 11'de yapıldı: şema genelinde güvenlik denetimi (kalıcı testle), hesap silme (soft delete + anonimleştirme),
KVKK aydınlatma metni taslağı. Kurallar: KARARLAR "Güvenlik denetimi", "Hesap silme", "KVKK aydınlatma metni".

Kod: `supabase/migrations/20261122152129_hesap_silme_guvenlik.sql`. Testler: `12_guvenlik.test.sql` (32),
`13_hesap_silme.test.sql` (25).

## Kalıcı denetim (`12_guvenlik.test.sql`)

Her test çalışmasında bütün `public` / `private` şeması taranır; yeni kod kuralı bozarsa test listeyle düşer:

- Her tabloda RLS açık; istemci rolleri hiçbir tabloya yazamaz; tek kolon izni `profiles` ad / soyad / bölüm.
- Anonim hiçbir tabloyu okuyamaz, hiçbir fonksiyonu çalıştıramaz, `private` şemaya giremez.
- Her fonksiyonda `search_path` sabit. `private`'ta giriş yapanın çalıştırabildiği yalnızca RLS yardımcıları
  (`current_school_id`, `has_permission`, `is_superadmin`, `my_cluster_ids`, `school_of_user`).
- Kimlik dizileri kapalı; okuma dışındaki tek politika `profiles_update_own`; anonime politika yok; view yok;
  Realtime yayını yok.
- **Varsayılan yetkiler:** postgres'in oluşturduğu yeni tablo / fonksiyon istemcilere kapalı başlar (Supabase'in
  "herkese aç" varsayılanı kaldırıldı). Yeni RPC'ye `grant execute ... to authenticated`, RLS'te kullanılan yeni
  yardımcıya da açıkça izin verilmeli (bu listeye eklenir).
- Saldırı denemeleri: rol / okul değiştirme, başka okulun profili, başkasının ledger / bakiye / gizli profili,
  `private` tablo, `post_ledger`, ledger'a ekleme, bahis silme, öğrencinin para / izin vermesi, sahte
  `service_role` iddiası, anonim okuma / yatırım.

## Denetim sonucu (2026-11-22)

| Konu | Durum |
|---|---|
| RLS, tablo / kolon yetkileri, search_path | Temiz |
| `private.bets_check_scope()` herkese açıktı (tetikleyici; doğrudan çağrılamaz) | Kapatıldı |
| Kimlik dizileri (`ledger_entries_id_seq` vb.) istemcilere açıktı (Supabase varsayılanı) | Kapatıldı |
| Varsayılan yetkiler yeni nesneyi istemcilere açıyordu | Kapatıldı (yukarıda) |
| Advisors: 38 × "authenticated SECURITY DEFINER çalıştırabilir" | Tasarım gereği: hepsi istemci RPC'si; her biri oturum + yetki + girdiyi içeride denetler, her birinin pgTAP ret testi var |
| Advisors: `public.rls_auto_enable()` anonim | Supabase'in kendi tetikleyicisi; dokunulmaz |
| Advisors: sızdırılmış şifre koruması kapalı | Kullanıcının işi (Auth ayarları) |
| Repoda / git geçmişinde sır | Yok (`.env*` yok sayılıyor; yalnızca `.env.example`) |
| Mobil / admin istemcisinde secret key | Yok (yalnızca publishable key; mobil `sb_secret_` görürse çalışmaz) |
| Storage bucket, Realtime, view | Yok |

## Kalite kontrolü ve çift kontrol (2026-11-22, Adım 12 sonrası)

- **Canlı API'ye anonim deneme** (yalnızca publishable key): şema (OpenAPI) gizli; 24 tablonun hepsi 42501; 37 RPC'nin hepsi doğru parametrelerle çağrılınca 42501; GraphQL kapalı; depolama boş. Auth: e-posta onayı zorunlu, anonim giriş kapalı, yalnızca e-posta sağlayıcısı.
- **Düzeltilen** (migration `20261122173731_qa_duzeltmeleri.sql`, testler 11 / 13, `para.mjs` 4b):
  - Aynı kişinin eşzamanlı XP'li görev ödülleri `40P01 deadlock` veriyordu (5 istekten 3'ü; testle yeniden üretildi):
    profil kilidi `FOR UPDATE` → `FOR NO KEY UPDATE` (`award_xp`, `delete_my_account`, `request_student_email_code`).
  - Silinen hesap, anahtarı geçerliyken okul maili kodu isteyip yeniden doğrulanabiliyor, düello açabiliyordu:
    `is_verified` / `current_school_id` silinmiş profili saymaz, kod isteği reddedilir.
  - Düello başlığındaki ad silmede temizlenir; Auth engeli `infinity` yerine 100 yıl; silinen kişi sıralamada gösterilmez.
  - Okulunda `gorev_yonet` olan o okulun görev ödülünü alamaz (kendine SP / XP basma).
  - Admin: çıkış `scope: local` (telefondaki oturumu kapatmaz); güvenlik başlıkları (çerçeveleme yasak, nosniff,
    referrer, izinler), `X-Powered-By` yok; anahtar `sb_publishable_` değilse çalışmaz. Mobil: aynı anahtar kuralı;
    `allowBackup=false` + veri aktarma kuralları (oturum anahtarları yedeğe girmez).

Kalan riskler [acik-isler](acik-isler.md)'de: hız sınırı yok, silinen hesabın anahtarı ≤ 1 saat geçerli, Supabase
güvenlik kayıtlarında e-posta.

## İstek bekçisi ve yasaklama (Adım 13)

- `guard.check_request()`: PostgREST her API isteğinden önce çağırır (`alter role authenticator set pgrst.db_pre_request`). Oturumdaki kişinin profili silinmiş ya da yasaklıysa `KB025`; anonim ve normal isteklerde hiçbir şey yapmaz. **Bozulursa bütün API durur:** değiştirince canlı API'yi hemen dene (anonim RPC denemesi + uygulama).
- `set_user_ban(user, banned, reason)`: yalnızca süperadmin; kendini ve süperadmini yasaklayamaz. Profilde `banned_at`, Auth'ta 100 yıl engel, oturumlar ve yenileme anahtarları silinir; gerekçe denetim kaydında (`user_ban` / `user_unban`).
- `reset_referee_strikes(user, note)`: süperadmin ya da kişinin okulunda `kullanici_bahsi_denetle`; kendine yapamaz.
- Admin: `/kullanicilar` (arama, yasakla / kaldır, ihtar sıfırla), `/sosyal-bahisler` (sonuç bekleyen ve açık sosyal bahisler, gerekçeyle iptal).

## Hesap silme

`public.delete_my_account()` (giriş yapan, kendisi için):
- Ret: anonim `42501`; profili yok / zaten silinmiş `P0002`; süperadmin `42501` (önce rolü SQL ile alınır);
  sonuçlanmamış (`open` / `locked` / `settling`) bahiste yatırımı ya da hakemliği varsa `KB024` (düello da bahistir).
- Yapılan (tek transaction, önce profil satırı kilitlenir):
  - `profiles`: "Silinmiş Kullanıcı", bölüm boş, rol öğrenci, `deleted_at`.
  - `profile_private`: okul maili ve doğrulama boş (mail başka hesaba bağlanabilir; kişi artık yatıramaz: `KB002`).
  - Okul maili kod kaydı ve geliştirme kutusundaki mailleri, izinleri, üyelikleri, liderlik satırları silinir;
    envanter kalır, hiçbir ürün kuşanılı kalmaz.
  - Supabase Auth: kimlikler, oturumlar, yenileme anahtarları, MFA, tek kullanımlık anahtarlar silinir; e-posta,
    telefon, şifre, kullanıcı metadatası boşaltılır; `banned_until = infinity`, `deleted_at`. Auth satırı kalır
    (profil ona bağlı); aynı e-postayla yeni kayıt olunabilir.
  - `admin_audit_log`'a `account_delete`.
- Kalan: ledger, yatırımlar, XP olayları, görev ödülleri, envanter (anonim profile bağlı; bütünlük ve başkalarının
  bahis sonuçları için).
- Silinen kişi sıralamaya girmez (`private.settled_wagers` süzer), okul özetinde üye sayılmaz, adını geri yazamaz
  (`profiles_update_own` politikası).
- Mobil: Profil > "Hesabımı sil" → onay penceresi (kutu işaretlenmeden düğme kapalı) → RPC → yerel çıkış.

## KVKK aydınlatma metni

- Tek kaynak: `mobile/assets/legal/kvkk_aydinlatma.txt` (uygulama `/kvkk` ekranında gösterir; girişten önce de
  açılır, kayıt ekranında bağlantısı var; Profil > "Gizlilik ve KVKK"). Biçim: `# ` başlık, `## ` ara başlık,
  `- ` madde.
- **Taslak:** hukuk incelemesi gerekli; köşeli parantezli yerler (veri sorumlusu, adres, iletişim e-postası,
  yurt dışı aktarım dayanağı, mail sağlayıcısı, güvenlik kaydı süresi) kullanıcı tarafından doldurulacak.
- İçerik: işlenen veriler, amaç ve hukuki sebep (m. 5), kimin gördüğü (okul arkadaşları, yetkililer, Supabase,
  mail sağlayıcısı), yurt dışına aktarım (AB / Frankfurt, m. 9), saklama ve silme, haklar (m. 11), başvuru.
