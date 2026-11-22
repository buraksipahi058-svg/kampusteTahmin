# Bölge: Admin paneli (Next.js)

Yönetici ve yetkili paneli, mobilden ayrı web uygulaması. Adım 6'da kuruldu: giriş, resmi bahisler,
yetkiler ve bakiye işlemleri. Panelde iş mantığı yok; her işlem yetkiyi kendisi denetleyen bir veritabanı
fonksiyonuna gider. Secret key kullanılmaz: kullanıcının kendi oturumuyla çalışır.

Kod: `admin/`. Next.js 16.4.6 (güvenlik yaması, 2026-11-22), React 19.3, Tailwind 4, TypeScript, `@supabase/ssr`.

## Çalıştırma

```bash
npm --prefix admin run dev     # http://localhost:3000  (.claude/launch.json: "admin")
npm --prefix admin run lint
npm --prefix admin run build
npm run db:types               # kökte: veritabanı tipleri -> admin/src/lib/supabase/database.types.ts
```

Yapılandırma: `admin/.env.local` (`NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`).

## Dosyalar (`admin/src/`)

| Dosya | Ne yapar |
|---|---|
| `proxy.ts` + `lib/supabase/proxy.ts` | Her istekte oturumu yeniler; oturum yoksa `/giris`'e, varsa `/giris`'ten `/`'a yönlendirir. `/_next/` yollarının tamamı hariç (yoksa geliştirmede `/_next/hmr` canlı yenileme bağlantısı da girişe yönlenir) |
| `lib/supabase/server.ts` | Sunucu tarafı istemci (çerezli oturum); `env.ts`, `fetch-with-timeout.ts` (araç servis projesinden) |
| `lib/auth.ts` | `getStaff()` (oturumdaki kişi: rol, izinler; öğrenciyse null), `can(staff, schoolId, key)`, izin etiketleri |
| `lib/errors.ts` | Veritabanı hata kodu → Türkçe mesaj (mobildekiyle aynı anlamlar) |
| `lib/format.ts` | Tarih (İstanbul), tutar, oran biçimi; `datetime-local` ↔ ISO (+03:00; `istanbulLocalToIso`, `isoToIstanbulLocal`) |
| `components/ui.tsx`, `user-search.tsx` | Gönder düğmesi, form mesajı; ada göre kullanıcı arama |
| `app/giris/` | Giriş formu + `login` / `logout` server action'ları |
| `app/gizlilik/`, `app/kosullar/`, `app/hesap-silme/` | **Oturumsuz** metin sayfaları (mağaza bağlantıları; `proxy.ts` `PUBLIC_PATHS`). KVKK metni ve kullanım koşulları `src/legal/*.txt` (mobildeki asset'lerin kopyası; mobil test aynılığını denetler), `lib/legal.ts` (`use cache` ile okur, derlemede statik), `components/legal-page.tsx` |
| `app/(panel)/layout.tsx` | `instant = false`; rol kontrolü (öğrenciye "yetkin yok"), menü |
| `app/(panel)/resmi-bahisler/` | Liste (seçenek, oran, yatırılan, olası ödeme), açık sabit oranlıda oran değiştirme (`update_official_bet_odds`), kilitle / sonuçlandır / iptal; `yeni/` açma formu |
| `app/(panel)/itirazlar/` | Moderatör (`kullanici_bahsi_denetle` / süperadmin): açık itirazlı sosyal bahisler, hakemin sonucu, havuz, itiraz gerekçeleri; onayla / değiştir / iptal (`resolve_social_dispute`) |
| `app/(panel)/gunun-tahmini/` | `resmi_bahis_ac` / `resmi_bahis_kapat` / süperadmin: Evet / Hayır sorusu açma (okul, soru, kapanış), havuzlar, kapanıştan sonra sonuç girme, iptal (`create/settle/cancel_daily_prediction`) |
| `app/(panel)/gorevler/` | `gorev_yonet` / süperadmin: görev ekleme (SP / SSP ödül + XP), `[id]/` düzenleme, aç / kapa (`save_quest`); eylem ve dönem etiketleri `labels.ts` |
| `app/(panel)/market/` | `market_yonet` / süperadmin: ürün ekleme (türe göre simge ya da renk, en az seviye), `[id]/` düzenleme (tür sabit), satışa aç / kaldır (`save_market_item`) |
| `app/(panel)/trivia/` | `trivia_yonet` / süperadmin: soru ekleme (okul ya da genel, 2–4 şık, doğru şık hazır seçili gelmez), `[id]/` düzenleme, açma / kapama (`save_trivia_question`) |
| `app/(panel)/istatistik/` | `analitik_gor` / süperadmin: okul seçimi, bu haftanın okul özeti (`school_stats`), liderlik tablosu (seviye sütunlu; dönem ve ölçüt bağlantıları `?okul=&olcut=&donem=`, `get_leaderboard` ilk 50). Menüde ilk sırada |
| `app/(panel)/kullanicilar/` | Süperadmin ve moderatör: kişi arama; yasakla / yasağı kaldır (süperadmin, `set_user_ban`), hakem ihtarını sıfırla (`reset_referee_strikes`) |
| `app/(panel)/sosyal-bahisler/` | Moderatör: kapanışı geçmiş ve sonucu girilmemiş, ayrıca açık sosyal bahisler; gerekçeyle iptal (`cancel_social_bet`) |
| `app/(panel)/yetkiler/` | Süperadmin: izin ver / geri al (`grant/revoke_permission`) |
| `app/(panel)/bakiye/` | Süperadmin: `admin_grant` / `admin_adjust`, son yönetim işlemleri |

## Bu Next.js sürümünün tuzakları

- **Formlar `ActionForm` ile** (`components/ui.tsx`): `<form action>` React 19'da her gönderimden sonra formu boşaltır, hata alan formda girilenler kaybolurdu. `ActionForm` eylemi elle çağırır (basılan düğmenin değeri dahil), başarıda boşaltır; `useActionState`'in üçüncü değeri (`pending`) verilir, `SubmitButton` onu kullanır.
- Çıkış `signOut({ scope: "local" })`: varsayılan global çıkış yetkilinin telefondaki oturumunu da kapatır.
- Güvenlik başlıkları `next.config.ts`'te (çerçeveleme yasak vb.); `env.ts` yalnızca `sb_publishable_` anahtarı kabul eder.

- `admin/AGENTS.md`: kod yazmadan önce `admin/node_modules/next/dist/docs/` altındaki ilgili rehberi oku.
- `cacheComponents` açık: oturum (çerez) okuyan sayfa ya `<Suspense>` içinde olmalı ya da segmentte `export const instant = false` olmalı; panel düzeni ikincisini kullanır.
- Veri değiştiren server action sonrası `refresh()` (`next/cache`); sayfalar önbelleksiz.
- supabase-js sorgu tipini yalnızca **tek parça** select metninden çıkarır; `"..." + "..."` ile bölünen metin `GenericStringError` tipine düşer.
- Bileşen içinde doğrudan `Date.now()` lint hatası (react-hooks/purity): `lib/format.ts` `isPast()`.
- Eski bir route silinince `.next/dev/types` bayat kalır, `tsc` hata verir: `.next` silinip `next typegen`.
- `next build` bilinen güvenlik açığı olan sürümde durup yükseltme önerir. 16.4.2'den 16.4.6'ya kullanıcı onayıyla `npm install next@16.4.6 eslint-config-next@16.4.6` ile geçildi (uyarının önerdiği `next upgrade --agent=security` komutu kullanılmadı); `npm audit` 0 açık.

## Durum

- Doğrulanan: lint, tip kontrolü, build temiz; oturumsuz istek girişe yönleniyor, giriş sayfası hatasız.
- Doğrulanmayan: giriş sonrası ekranlar tarayıcıda denenmedi (kullanıcının şifresiyle giriş gerekiyor; hesap ayrıca yetkili/süperadmin olmalı). Arkasındaki veritabanı fonksiyonları pgTAP ve uçtan uca SQL ile denendi.
- İtiraz kuyruğu (Adım 7), trivia soruları ve günün tahmini (Adım 8), görevler ve market (Adım 9), istatistik ve XP / seviye alanları (Adım 10) build ve tip kontrolünden geçti; giriş sonrası tarayıcıda denenmedi (aynı sebep). `/gunun-tahmini`, `/gorevler`, `/market/[id]`, `/istatistik` oturumsuz istekte girişe yönleniyor (denendi).
- Üretilen tiplerde RPC parametreleri null alamıyor görünür; null gönderilmesi gereken yerde (`save_trivia_question` `p_id` / genel soru) `as unknown as string` kullanıldı.
- Sonra: ürün satış / görev tamamlama sayıları, zaman içindeki eğilimler (grafik), kullanıcı yönetimi (ban).
