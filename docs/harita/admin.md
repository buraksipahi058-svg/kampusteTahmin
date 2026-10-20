# Bölge: Admin paneli (Next.js)

Yönetici ve yetkili paneli, mobilden ayrı web uygulaması. Şu an yalnızca Supabase bağlantısını
gösteren tek sayfa var. Asıl ekranlar Adım 6'da.

Kod: `admin/`. Next.js 16.4, React 19.3, Tailwind 4, TypeScript.

## Çalıştırma

```bash
npm --prefix admin run dev     # http://localhost:3000
npm --prefix admin run lint
npm --prefix admin run build
```

Yapılandırma: `admin/.env.local` (`NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`); örnek `admin/.env.example`.
Secret key kullanılmaz: admin kullanıcının kendi oturumuyla çalışır, yetkiyi veritabanı kontrol eder.

## Bu Next.js sürümünün tuzakları

- `admin/AGENTS.md`: kod yazmadan önce `admin/node_modules/next/dist/docs/` altındaki ilgili rehberi oku; API'ler eğitim verisinden farklı olabilir.
- `cacheComponents` açık: istek anında veri okuyan kısım (`fetch`, `cookies()`, `connection()`) `<Suspense>` içinde olmalı, yoksa build kırılır (`blocking-prerender-dynamic`). Örnek: `admin/src/app/page.tsx`.
- `npm run db:types` (kök) tipleri `admin/src/lib/supabase/database.types.ts`'e yazar; klasör henüz yok, ilk Supabase istemcisiyle birlikte oluşturulacak.

## Adım 6 planı (henüz başlanmadı)

- `@supabase/ssr` ile oturum; giriş yalnızca `yetkili` / `superadmin` rolüne.
- Ekranlar (MIMARI §8.2): dashboard, resmi bahisler (aç/kilitle/sonuçlandır/iptal), itiraz kuyruğu (Adım 7), görev ve market yönetimi (Adım 9), kullanıcı yönetimi, SSP ver / bakiye düzelt (yalnızca süperadmin: `admin_grant` / `admin_adjust`), yetki yönetimi (`grant/revoke_permission`).
- Her işlem veritabanındaki yetki kontrollü RPC'ye gider; panelde iş mantığı yok.
