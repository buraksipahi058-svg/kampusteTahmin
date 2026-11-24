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

Kalan riskler [acik-isler](acik-isler.md)'de (Supabase güvenlik kayıtlarında e-posta vb.). Silinen hesabın anahtarı
ve hız sınırı Adım 13-14'te kapatıldı (aşağıda).

## İstek bekçisi ve yasaklama (Adım 13)

- `guard.check_request()`: PostgREST her API isteğinden önce çağırır (`alter role authenticator set pgrst.db_pre_request`). Oturumdaki kişinin profili silinmiş ya da yasaklıysa `KB025`; anonim ve normal isteklerde hiçbir şey yapmaz. **Bozulursa bütün API durur:** değiştirince canlı API'yi hemen dene (anonim RPC denemesi + uygulama).
- `set_user_ban(user, banned, reason)`: yalnızca süperadmin; kendini ve süperadmini yasaklayamaz. Profilde `banned_at`, Auth'ta 100 yıl engel, oturumlar ve yenileme anahtarları silinir; gerekçe denetim kaydında (`user_ban` / `user_unban`).
- `reset_referee_strikes(user, note)`: süperadmin ya da kişinin okulunda `kullanici_bahsi_denetle`; kendine yapamaz.
- Admin: `/kullanicilar` (arama, yasakla / kaldır, ihtar sıfırla), `/sosyal-bahisler` (sonuç bekleyen ve açık sosyal bahisler, gerekçeyle iptal).

## Gizlilik ve istek sınırı (Adım 14)

Kod: `supabase/migrations/20261122200659_gizlilik.sql`. Test: `15_gizlilik.test.sql` (36).

- **Sıralamadan çıkma:** `set_leaderboard_hidden(hidden)` → `profile_private.leaderboard_hidden` (yalnızca kişi ve okulunda `kullanici_yonet` görür). Gizlenince sıralama satırları hemen silinir; `store_leaderboard` gizliyi hiç saymaz (sırada boşluk olmaz), `get_leaderboard` artakalan satırı da göstermez. Açınca sonraki hesaplamada (≤ 10 dk) döner; donmuş geçmiş haftalara dönmez. Okul özeti ve kişinin kendi istatistikleri etkilenmez.
- **Veri dışa aktarma:** `export_my_data()` → tek JSON (`format: kampusbet-verilerim-2`; 2. sürümde düello rolü, başarımlar, bildirimler, kampüs görevi gönderileri eklendi); Adım 19'da `word_puzzles` (kampüs kelimesi denemeleri) eklendi, `export_my_data` artık eski gövdeyi (`private.export_my_data_base`) çağıran sarmalayıcı: hesap (Auth e-postası, tarihler), profil, gizli profil, bakiye, seri, üyelik, izin, ledger, yatırımlar, açtığı / hakemlik yaptığı bahisler, itirazlar, düello oyunları, görev ödülleri, envanter, XP, sıralama satırları, yetkililerin kişi hakkındaki kayıtları (yapanın kimliği yok) ve kişinin kendi yönetim işlemleri. Başkasının kimliği, e-postası, adı girmez (test denetler). Silinmiş hesap alamaz. Mobil: Profil > Gizlilik > "Verilerimi indir" → `kampusbet-verilerim-YYYYAAGG.json` paylaş menüsüyle (`share_plus`, dosya önce uygulamanın geçici klasörüne yazılır).
- **İstek sınırı:** `guard.check_request()` giriş yapmış kişinin **yazma** isteklerini sayar: salt okunur transaction'lar (tablo okumaları, `stable` RPC'ler: `my_progress`, `my_quests`, `my_stats`, `get_leaderboard`, `school_stats`) sayılmaz. Son bir dakikada `economy_settings.api_write_limit_per_minute` (varsayılan 60) isteğe ulaşan `KB026` alır. Sayaç `private.request_log` (unlogged, istemciye kapalı), `kampusbet_istek_sayaci` 10 dakikada bir 5 dakikadan eskileri siler. **Sınır:** başarısız istek transaction'la geri alındığı için sayılmaz; IP başına sınır yok (anonim zaten hiçbir şey yapamaz). Tam koruma için önüne ağ geçidi (ör. Cloudflare) gerekir. Supabase Auth'un kendi giriş / kayıt / mail sınırları ayrıca var (panelde Rate Limits).
- **Kullanım koşulları:** tek kaynak `mobile/assets/legal/kullanim_kosullari.txt` (mobil `/kosullar`, girişten önce de açılır; admin'de oturumsuz `/kosullar`, kopyanın aynılığını ve sürümünü `app_info_test` denetler). Kayıtta "18 yaşını doldurdum; Kullanım Koşulları'nı okudum ve kabul ediyorum" kutusu zorunlu; kabul edilen sürüm Supabase Auth kullanıcı metadatasına `terms_version` (`AppInfo.termsVersion`) olarak yazılır. **Taslak:** hukuk incelemesi, köşeli parantezler (işletmeci, iletişim, yetkili mahkeme), yaş sınırı kararı.

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
  Adım 14: sıralamadan çıkma, uygulamadan veri indirme ve istek sayacı eklendi (admin kopyası da).

## Genel güvenlik kontrolü 2 (2026-11-23, Adım 17b sonrası)

Kod: `supabase/migrations/20261122223007_guvenlik_duzeltmeleri.sql`. Test: `22_guvenlik_duzeltmeleri.test.sql` (45),
`12_guvenlik` (+2: profil okuma kolonları).

Yapılan: kodu görmeden bağımsız saldırgan gözüyle inceleme (veritabanı, admin, mobil), Supabase advisors, girişsiz
canlı API denemesi (29 tablo kapalı, depolama listesi boş, genel adres yok, anonim yükleme reddedildi, GraphQL kapalı,
şema gizli), repoda ve git geçmişinde sır taraması (yok), admin `npm audit` (0), canlı depolama / politika / zamanlanmış
iş denetimi (7 iş, son 6 saatte hepsi başarılı).

| Bulgu | Önem | Düzeltme |
|---|---|---|
| Oran değiştirebilen (`resmi_bahis_ac`) resmi bahsin oranını yükseltip yatırabiliyordu | Orta | `place_wager`: `resmi_bahis_ac` sahibi de yatıramaz |
| Kampüs görevi yetkilisi sınırsız SP / XP'li görev açıp kodu arkadaşlarına verebiliyordu; SSP görevinin QR'ını ve onayını yetkili de yapabiliyordu | Orta | Yetkili görevinde tavan (`economy_settings.campus_task_staff_max_reward` 100 SP, `campus_task_staff_max_xp` 50 XP); kişi başı günde 5 görev (`campus_task_daily_limit`, `KB035`); SSP görevinde QR, QR yenileme ve onay yalnızca süperadmin |
| Kayıtta okul seçen herkes (okul maili doğrulamadan) okulun öğrenci adlarını, bahislerini, sıralamasını okuyabiliyordu | Orta (KVKK) | `current_school_id()` / `my_cluster_ids()` yalnızca okul maili doğrulanmış öğrenciye ya da yetkiliye okul döndürür; `get_leaderboard` doğrulanmamışa `KB002`. Mobilde boş liste yerine doğrulama kartı |
| İptal olan (rakipsiz) düellodan bedava cevap anahtarı toplanabiliyordu | Düşük-orta | `trivia_duel_review` yalnızca sonuçlanmış düelloda |
| Fotoğraf depolama doldurulabilirdi (sayım kilitsiz, günlük sınır yok, 2 MB) | Düşük | 1 MB; saatte 10 + günde 30; sayım kişi başı danışma kilidinden sonra |
| Kendi gönderisini (sonradan yetki alınca) onaylama; yasaklı / silinmiş hesaba ödül | Düşük | `review_campus_submission`: kendi gönderisi `42501`, kapalı hesabı onaylama `KB036` (yalnızca ret) |
| Gizli başarımın adı / açıklaması tablodan okunabiliyordu; yasak bilgisi okul arkadaşlarına açıktı | Düşük | `achievements_select`: gizli olanı yalnızca açan ve süperadmin görür. `profiles.banned_at` istemciye kapalı (kolon bazlı okuma izni); admin `banned_users(ids)` ile okur |
| Yasaklı / silinmiş yetkili Storage API'den fotoğraf okuyabiliyordu (bekçi Storage'a uygulanmaz) | Düşük | `campus_proof_readable` okuyanın yasaklı / silinmiş olmadığını denetler |
| Veri dışa aktarmada bildirimler, başarımlar, kampüs gönderileri, düellolar yoktu | KVKK | Biçim 2 |

Temiz bulunan: bütün `SECURITY DEFINER` fonksiyonlarda `search_path` sabit, dinamik SQL yok, anonime yalnızca bekçi
açık; para yarışları (başarım / görev ödülü, QR / fotoğraf gönderisi, onay, günlük ödül, sonuçlandırma); okul
sınırları; depolama adı kuralı ve üzerine yazamama; QR kodu (48 bit, anahtar API'ye kapalı); admin'de yalnızca
publishable anahtar, arama girdisi temizleniyor, açık yönlendirme yok; mobilde sır yok, bağlantılar yalnızca uygulama
içi. Advisors: yalnızca bilinen uyarılar (RPC'ler tasarım gereği, `rls_auto_enable`, sızdırılmış şifre koruması).
Kalan riskler [acik-isler](acik-isler.md)'de.

## Genel güvenlik kontrolü 3 (2026-11-24, Adım 19 sonrası)

Kod: `supabase/migrations/20261124084204_kelime_guvenlik_ipucu.sql`. Test: `24_kelime_guvenlik_ipucu.test.sql` (27).
Kapsam: `d937b4f..ae8bce1` (Oyunlar menüsü, tasarım 18a–18e, logo, öğretici, kampüs kelimesi).

Yapılan: yeni değişikliklerin kodu görmeden bağımsız saldırgan gözüyle incelenmesi (en çok kampüs kelimesi), Supabase
advisors (yeni tür yok), admin `npm audit` (0), son 8 commit'te ve repoda sır taraması (yok), release APK'da sır
taraması (yalnızca publishable anahtar), girişsiz canlı API denemesi (yeni tablolar ve 6 yeni fonksiyon 401, `private`
şema açık değil, şema listesi kapalı), `user_metadata`'ya güvenen SQL / admin kodu yok (öğretici bilgisi yalnızca
arayüz), zamanlanmış işler (7 iş, son 6 saatte hatasız), canlı bakiye / XP tutarlılığı (uyuşmazlık 0).

| Bulgu | Önem | Düzeltme |
|---|---|---|
| Sözlükte olmayan cevap, sözlük dışı tahminlerin hak harcamadan "cevap mı?" diye denenmesiyle bulunabiliyordu (başarısız istek hız sınırına da girmiyor) | Orta | Girilen kelime sözlüğe eklenir, cevap istisnası kalktı; bitmiş oyunda `KB039` sözlük kontrolünden önce |
| Gün içinde okula kelime eklenince (ya da bugüne taşınınca) genel kelimeyi bitiren ikinci oyun ve ikinci ödül alabiliyordu | Düşük | Kişi günde tek bulmaca oynar (`word_puzzle_for_user`); bugün genel kelime varken okula bugün için kelime `KB041` |
| Ödül engeli yalnızca o anki izne bakıyordu: izni kalkacak yetkili ileri tarihli kelimeleri görüp sonra tam ödül alabilirdi | Düşük | `private.word_puzzle_viewers` (giren, yönetim listesinde gören) ödül almaz |
| Kelime düzenleme ile ilk tahmin arasında yarış (eski kelimeyle işaretleme) | Bilgi | Tahmin bulmaca satırını `FOR SHARE` kilitler |
| Kelimeyi giren yetkilinin kimliği öğrencilere açıktı | Bilgi | `word_puzzles.created_by` kolon bazlı okumayla kapalı |

Bilgi (önlenemez): yetkili kelimeyi arkadaşlarına söyleyebilir; tespit için yönetim listesinde "ilk tahminde bulan"
sayısı var. Bilinen sınır: istek bekçisi yalnızca başarılı yazma isteklerini sayar ([acik-isler](acik-isler.md)).
Temiz bulunan: cevap yalnızca oyun bitince dönüyor, başka hiçbir yol `word_answers`'a dokunmuyor, tahmin kapsamı
(dün / yarın / başka okul / genel) doğru, RLS önceliği ve NULL doğru, deneme kilidi ödülü tek seferlik kılıyor, XP /
ledger kısıtlarında önceki nedenler korunmuş, yönetim izinleri ve denetim kaydı, `export_my_data` sarmalayıcısı,
admin'de XSS / açık yönlendirme / sır yok, mobilde cevap ya da sözlük yok.
