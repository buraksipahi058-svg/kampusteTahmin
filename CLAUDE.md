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

Şema yalnızca `supabase/migrations` ile değişir; Supabase panelinden elle tablo/politika değiştirilmez. Supabase URL ve publishable key `.env` dosyalarında durur, repoya girmez.
