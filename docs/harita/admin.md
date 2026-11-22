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
| `lib/format.ts` | Tarih (İstanbul), tutar, oran biçimi; `datetime-local` → ISO (+03:00) |
| `components/ui.tsx`, `user-search.tsx` | Gönder düğmesi, form mesajı; ada göre kullanıcı arama |
| `app/giris/` | Giriş formu + `login` / `logout` server action'ları |
| `app/(panel)/layout.tsx` | `instant = false`; rol kontrolü (öğrenciye "yetkin yok"), menü |
| `app/(panel)/resmi-bahisler/` | Liste (seçenek, oran, yatırılan, olası ödeme), kilitle / sonuçlandır / iptal; `yeni/` açma formu |
| `app/(panel)/yetkiler/` | Süperadmin: izin ver / geri al (`grant/revoke_permission`) |
| `app/(panel)/bakiye/` | Süperadmin: `admin_grant` / `admin_adjust`, son yönetim işlemleri |

## Bu Next.js sürümünün tuzakları

- `admin/AGENTS.md`: kod yazmadan önce `admin/node_modules/next/dist/docs/` altındaki ilgili rehberi oku.
- `cacheComponents` açık: oturum (çerez) okuyan sayfa ya `<Suspense>` içinde olmalı ya da segmentte `export const instant = false` olmalı; panel düzeni ikincisini kullanır.
- Veri değiştiren server action sonrası `refresh()` (`next/cache`); sayfalar önbelleksiz.
- Bileşen içinde doğrudan `Date.now()` lint hatası (react-hooks/purity): `lib/format.ts` `isPast()`.
- Eski bir route silinince `.next/dev/types` bayat kalır, `tsc` hata verir: `.next` silinip `next typegen`.
- `next build` bilinen güvenlik açığı olan sürümde durup yükseltme önerir. 16.4.2'den 16.4.6'ya kullanıcı onayıyla `npm install next@16.4.6 eslint-config-next@16.4.6` ile geçildi (uyarının önerdiği `next upgrade --agent=security` komutu kullanılmadı); `npm audit` 0 açık.

## Durum

- Doğrulanan: lint, tip kontrolü, build temiz; oturumsuz istek girişe yönleniyor, giriş sayfası hatasız.
- Doğrulanmayan: giriş sonrası ekranlar tarayıcıda denenmedi (kullanıcının şifresiyle giriş gerekiyor; hesap ayrıca yetkili/süperadmin olmalı). Arkasındaki veritabanı fonksiyonları pgTAP ve uçtan uca SQL ile denendi.
- Sonra: itiraz kuyruğu (Adım 7), görev ve market yönetimi (Adım 9), analitik.
