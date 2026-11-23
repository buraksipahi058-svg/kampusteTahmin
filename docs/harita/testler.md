# Bölge: Testler

İki tür test var: tek bağlantıda çalışan pgTAP testleri ve gerçek paralel isteklerle eşzamanlılık
testleri. İkisi de buluttaki veritabanında çalışır.

## Durum

| Dosya | Kapsam | Sayı |
|---|---|---|
| `supabase/tests/database/01_kumeler_profiller_yetkiler.test.sql` | kümeler, profiller, RLS, yetkiler | 52 |
| `supabase/tests/database/02_para_cekirdegi.test.sql` | ledger, bakiye, seri, admin para | 47 |
| `supabase/tests/database/03_bahis_cekirdegi.test.sql` | bahis açma, yatırım, dağıtım, iptal | 61 |
| `supabase/tests/database/04_okul_maili.test.sql` | okul maili kodu, sınırlar, geliştirme kutusu, Brevo kuyruğu | 32 |
| `supabase/tests/database/05_resmi_bahis.test.sql` | resmi bahis yetkileri, sabit oranlı ödeme, iptal, denetim kaydı | 37 |
| `supabase/tests/database/06_sosyal_havuz.test.sql` | sosyal bahis açma, hakem, itiraz, moderatör, ihtar, zamanlanmış iş | 54 |
| `supabase/tests/database/07_trivia_duellosu.test.sql` | soru yönetimi, meydan okuma, oynama, puanlama, süreler, cron | 45 |
| `supabase/tests/database/08_gunun_tahmini.test.sql` | günün tahmini açma, yatırma (düello hâlâ kapalı), sonuç, iptal, zamanlanmış iş, kısıt | 45 |
| `supabase/tests/database/09_gorevler_market.test.sql` | görev / ürün yönetimi izinleri, görünürlük, her eylemin sayımı, ödül (bir kez), dönemler, satın alma, kuşanma, satıştan kalkan ürünün görünürlüğü | 72 |
| `supabase/tests/database/10_liderlik.test.sql` | sıralama değerleri (isabet eşiği, düello hariç, eşit sıra, haftalar arası seri, geçen hafta), ilk N + kendi satırı, kozmetik, okul ayrımı, `analitik_gor`, RLS, `my_stats`, `school_stats`, biten haftanın donması, cron | 42 |
| `supabase/tests/database/11_xp_seviye.test.sql` | seviye eğrisi, günlük giriş / görev / doğru tahmin XP'si, iptal, günlük sınır, tekrar engeli, kaynak kısıtı, `my_progress`, `xp_events` RLS, seviyeli ürün (`KB023`), liderlikte seviye, ayar kısıtı | 38 |
| `supabase/tests/database/12_guvenlik.test.sql` | şema değişmezleri (RLS, yazma yetkisi, anonim, search_path, private yardımcıları, diziler, politikalar, view, Realtime, varsayılan yetkiler) + saldırı denemeleri | 32 |
| `supabase/tests/database/13_hesap_silme.test.sql` | silme engelleri (`KB024`, süperadmin), anonimleştirme, Auth temizliği, kalan kayıtlar, sıralama / okul özeti, mailin yeniden kullanımı, silindikten sonra kod / düello reddi, düello başlığı | 29 |
| `supabase/tests/database/14_yonetim.test.sql` | istek bekçisi (ayar, silinmiş / yasaklı / normal / anonim), yasaklama (izin, gerekçe, Auth, oturumlar, denetim, kaldırma), ihtar sıfırlama (okul sınırı), oran değiştirme (izin, sayı, aralık, havuzlu, kapalı bahis, eski yatırım) | 31 |
| `supabase/tests/database/15_gizlilik.test.sql` | sıralamadan çıkma (izin, ret, okul arkadaşı göremez, satırlar silinir, yeniden hesaplamada yok, sırada boşluk yok, artakalan satır gösterilmez, geri dönüş), veri dışa aktarma (anonim / silinmiş ret, içerik, başkasının verisi yok), istek sınırı (sınır, kişi başına, anonim, sayaç tablosu kapalı, eski istekler, temizlik, salt okunur istek) | 36 |
| `supabase/tests/database/16_mobil_eksikler.test.sql` | kişi arama (anonim / profilsiz / kısa sorgu ret, yalnızca doğrulanmış okul arkadaşı, hakem olabilirlik, büyük / küçük harf, LIKE karakterleri), düello cevapları (bitmeden ret, oyuncu görür, kendi ve rakip cevabı, oyuncu olmayan / anonim / hiç oynamayan ret) | 17 |
| `supabase/tests/database/17_basarimlar.test.sql` | başarım kataloğu ve RLS (anonim, ekleme yasağı, okul arkadaşı görür, başka okul görmez), ölçütler, ilerleme, gizli başarım, ödül alma (`KB027`, `KB028`, `P0002`, ledger, XP, yalnızca eklenir), okulda kazanan oranı, günlük ödül takvimi (ilk gün, bonus, alınınca, süren seri, kopan seri) | 32 |
| `supabase/tests/database/18_basarim_yonetimi.test.sql` | başarım yönetimi: anonim / öğrenci / görev yöneten yetkili ret, süperadmin ekler (katalog, denetim), ölçüt / kademe / boş alan / tekrar anahtar ret, düzenleme, anahtar değişmez, olmayan, kapatılan kazananda kalır ve kazanmayana görünmez | 15 |
| `supabase/tests/concurrency/para.mjs` | günlük ödül, eşzamanlı düşüm, eşzamanlı profil, aynı görev ödülü, aynı kişinin XP'li farklı görev ödülleri (kilitlenme), aynı başarım ödülü, aynı ürün (+ bütünlük: bakiye, XP) | 9 kontrol |
| `supabase/tests/concurrency/bahis.mjs` | eşzamanlı yatırım, çift yatırım, sonuç yarışı, çift sonuç (+ bütünlük: bakiye, XP) | 6 kontrol |

Son durum: hepsi geçiyor (Adım 16 eksikleri sonu: 717 pgTAP, 60 Flutter. Adım 16 sonu: 702 pgTAP, 58 Flutter, para 9/9, bahis 6/6. Adım 15 sonu: 670 pgTAP, 57 Flutter. Adım 14 sonu: 653 pgTAP, 50 Flutter. Adım 13 sonu: 617 pgTAP. Kalite kontrolü sonu: 586 pgTAP, para 8/8, bahis 6/6. Adım 11 sonu: 581 pgTAP; Adım 11 para / bahis koduna dokunmadığı için eşzamanlılık yeniden çalıştırılmadı. Adım 10 + XP sonu: eşzamanlılık para 7/7, bahis 6/6 — XP tetikleyicileri para ve
bahis transaction'larının içinde çalıştığı için yeniden çalıştırıldı). `cleanupWorld` XP olaylarını ve liderlik
satırlarını da siler (10 dakikalık iş test okulunu hesaplamış olabilir).

pgTAP'te sıralama gibi zamana bağlı hesaplar için bahis `private.settle_bet` ile sonuçlandırılıp `settled_at`
elle verilir (`private.week_bounds(0)` başına dakika eklenerek); yatırımlar `private.stake_wager` ile (10 dosyası).

## Çalıştırma

```bash
npm run db:test               # pgTAP; Docker Desktop açık olmalı
npm run db:test:concurrency   # ~5 dk; kökteki .env.local içinde SUPABASE_DB_PASSWORD gerekir
```

## pgTAP yazma kuralları

- Dosya `begin;` ile başlar, `rollback;` ile biter → buluta veri bırakmaz.
- İkinci satır `set local role postgres;` (CLI'ın test rolü postgres yetkilerini devralmaz). Kullanıcı rolünden geri dönerken de `reset role` yerine bu.
- Sonra `create extension if not exists pgtap with schema extensions; set local search_path = public, extensions; select plan(N);`
- Kullanıcı gibi davranmak: `set local role authenticated; set local request.jwt.claims to '{"sub":"<uuid>","role":"authenticated"}';` Anonim: `set local role anon;`.
- Hazırlıkta çok kullanıcılı profil açmak için DO bloğu: `perform set_config('request.jwt.claims', ..., true); perform public.create_profile(...);`
- Sonuç satırı üreten yardımcı çağrıları (`select private.lock_bet(...)`) DO + `perform` içine al; TAP çıktısına satır karışmasın.
- Hata beklerken dört argümanlı biçim: `throws_ok($$...$$, 'KB001', null, 'açıklama')`.
- Tarih sırası gerektiren kontrollerde aynı transaction'daki `now()` sabittir; sıra için `created_at` yerine farklı değerler kullan.
- Sabit uuid'ler: okullar `a0..` / `b0..`, kişiler `c0..`. Bahis kimlikleri geçici `t` tablosunda, `pg_temp.bet(k)` / `pg_temp.opt(k, sıra)` yardımcılarıyla (03 dosyası).
- Testler buluttaki gerçek verinin varlığına dayanmamalı (sayımlar test kimlikleriyle süzülür) ama genel bütünlük kontrolleri (`balance_mismatches` boş) tüm veride çalışır.
- Her yeni tablo / politika / fonksiyon için en az bir izin + bir ret testi.
- `pg_temp` yardımcı fonksiyonları kullanıcı rolüyle (`authenticated`) çağrılacaksa dosyanın başına (search_path'ten sonra) `alter default privileges for role postgres grant execute on functions to public;` yaz: Adım 11'den beri yeni fonksiyonlar varsayılan olarak kapalı (satır transaction'la birlikte geri alınır). `12_guvenlik` bu satırı kullanmaz.
- `auth.identities` / `auth.sessions`'a test satırı eklenebilir (hesap silme testi, 13 dosyası).

## Eşzamanlılık testleri

- Ortak kod: `supabase/tests/concurrency/lib.mjs` (`runSql`, `parallel`, `createWorld`, `setupWorld`, `cleanupWorld`, `checkLedgerIntegrity`, `runSuite`).
- Her istek ayrı bir `npx supabase db query --linked` süreci; hepsi `pg_sleep_until` ile aynı ana kilitlenir. Çıktıdaki "zamanında başlayan: n/n" gerçekten eşzamanlı başladıklarını gösterir.
- Gerçek veri yazar: rastgele adlı bir test okulu ve kullanıcılar; sonunda (hata olsa bile) siler. Silmek için ledger koruma tetikleyicisi tek transaction içinde kapatılıp açılır. **Yalnızca geliştirme projesinde.**
- Yeni senaryo eklerken: `lib.mjs`'teki `cleanupWorld`, yeni tablolardaki test verisini de silecek şekilde güncellenmeli.
- Takılan istek 90 sn'de kesilir (`TIMEO`).
