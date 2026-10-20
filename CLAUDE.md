# KampüsBet — Proje Kuralları

## Önce haritaya bak

- Amaç az bağlamla anlamak: oturum başında `docs/HARITA.md`'yi oku (neredeyiz, sıradaki iş, görev → hangi bölge).
- Sonra yalnızca görevin bölge dosyalarını aç (`docs/harita/*.md`). Migration, test ve `KARARLAR.md` / `MIMARI.md` dosyalarını baştan sona okuma; bölge dosyası nereye bakacağını söyler.
- Adım bitince `HARITA.md`'nin "Şu an" bölümünü ve değişen bölge dosyasını güncelle; yeni karar `KARARLAR.md`'ye tek satır.

## Çalışma şekli

- Adım adım ilerle; her adımın sonunda dur, raporla ve onay bekle. Commit yalnızca kullanıcı isteyince.
- Kullanıcıyla Türkçe konuş.

## Değişmez kurallar

- MIMARI §2 tartışılmaz: gerçek para yok ve nakde çevrilmez, market pay-to-win değil, ledger tek gerçek (yalnızca eklenir), SSP prestiji korunur, `cluster_id` baştan var. Kullanıcılar arası SP/SSP transferi yok.
- Supabase secret / service role key asla mobil uygulamaya ya da admin panelinin tarayıcıda çalışan koduna girmez. Kökteki `.env.local` (veritabanı şifresi) okunmaz, yazdırılmaz.
- Bakiye yalnızca `private.post_ledger` ile, tek transaction içinde, veritabanında değişir. Kilit sırası: bahis satırı, sonra bakiyeler `user_id` sırasıyla.
- Şema yalnızca `supabase/migrations` ile değişir; buluta gönderilmiş migration düzenlenmez, düzeltme yeni migration olur. Kalıplar ve kontrol listesi: `docs/harita/veritabani.md`.
- Her yeni tablo, RLS politikası ve fonksiyon için en az bir izin + bir ret testi. Test kuralları: `docs/harita/testler.md`.

## Klasörler

| Klasör | İçerik | Bölge |
|---|---|---|
| `mobile/` | Flutter öğrenci uygulaması | `docs/harita/mobil.md` |
| `admin/` | Next.js yönetim paneli | `docs/harita/admin.md` |
| `supabase/` | Migration, seed, testler (Supabase Cloud) | `docs/harita/veritabani.md` |
| `docs/` | Harita, kararlar, mimari | `docs/HARITA.md` |
