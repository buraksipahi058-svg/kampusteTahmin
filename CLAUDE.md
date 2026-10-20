# KampüsBet — Proje Kuralları

- Mimari: `docs/MIMARI.md`. Alınan kararlar ve onay bekleyen öneriler: `docs/KARARLAR.md`. Kararsız kalınca önce bu iki dosyaya bak.
- Adım adım ilerle; her adımın sonunda dur, raporla ve onay bekle. Adım planı `docs/KARARLAR.md`'de.
- Değişmez ilkeler (MIMARI §2) tartışılmaz: gerçek para yok ve nakde çevrilmez, market pay-to-win değil, ledger tek gerçek (append-only), SSP prestiji korunur, `cluster_id` baştan var.
- Supabase secret / service role key asla mobil uygulamaya ya da admin panelinin tarayıcıda çalışan koduna girmez.
- Bakiyeyi değiştiren her işlem tek bir atomik transaction içinde, veritabanı tarafında yapılır.

## Klasörler ve nerede çalıştıkları

| Klasör | İçerik | Nerede çalışır |
|---|---|---|
| `mobile/` | Flutter öğrenci uygulaması | Windows (Flutter SDK: `C:\Users\burak\dev\flutter`) |
| `admin/` | Next.js admin / yetkili paneli | Windows |
| `supabase/` | Migration, seed, SQL testleri | Supabase Cloud (CLI kökteki `package.json` ile: `npx supabase ...`) |
| `docs/` | Mimari ve kararlar | — |

Şema yalnızca `supabase/migrations` ile değişir; Supabase panelinden elle tablo/politika değiştirilmez. Buluta gönderilmiş bir migration dosyası düzenlenmez, düzeltme yeni migration olarak yazılır. Supabase URL ve publishable key `.env` dosyalarında durur, repoya girmez.

## Veritabanı testleri

- `supabase/tests/database/*.test.sql` (pgTAP). Çalıştırma: kökte `npm run db:test` (Docker Desktop açık olmalı).
- Testler buluttaki veritabanında tek transaction içinde çalışır ve `rollback` ile biter; veri bırakmamalı.
- CLI'ın test rolü `postgres` yetkilerini devralmaz: her test dosyası `set local role postgres;` ile başlar, kullanıcı rolünden geri dönerken de `reset role` yerine bu kullanılır.
- Her yeni tablo, RLS politikası ve fonksiyon için en az bir izin + bir ret testi yazılır.
- Yarış koşulu testleri `supabase/tests/concurrency/` altında: `npm run db:test:concurrency` (kökteki `.env.local` içinde `SUPABASE_DB_PASSWORD` gerekir). Şifresiz `supabase` CLI komutları paralel çalıştırılmaz.

## Para kuralları

- Bakiye yalnızca `private.post_ledger` ile değişir; başka hiçbir kod `balances` veya `ledger_entries`'e yazmaz.
- Birden fazla kullanıcının bakiyesine dokunan işlemler kullanıcıları `user_id` sırasıyla işler.
- `KB001` = yetersiz bakiye.
