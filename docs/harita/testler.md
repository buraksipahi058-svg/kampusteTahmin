# Bölge: Testler

İki tür test var: tek bağlantıda çalışan pgTAP testleri ve gerçek paralel isteklerle eşzamanlılık
testleri. İkisi de buluttaki veritabanında çalışır.

## Durum

| Dosya | Kapsam | Sayı |
|---|---|---|
| `supabase/tests/database/01_kumeler_profiller_yetkiler.test.sql` | kümeler, profiller, RLS, yetkiler | 52 |
| `supabase/tests/database/02_para_cekirdegi.test.sql` | ledger, bakiye, seri, admin para | 47 |
| `supabase/tests/database/03_bahis_cekirdegi.test.sql` | bahis açma, yatırım, dağıtım, iptal | 61 |
| `supabase/tests/concurrency/para.mjs` | günlük ödül, eşzamanlı düşüm, eşzamanlı profil | 4 senaryo |
| `supabase/tests/concurrency/bahis.mjs` | eşzamanlı yatırım, çift yatırım, sonuç yarışı, çift sonuç | 5 senaryo |

Son durum: hepsi geçiyor (Adım 3 sonu).

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

## Eşzamanlılık testleri

- Ortak kod: `supabase/tests/concurrency/lib.mjs` (`runSql`, `parallel`, `createWorld`, `setupWorld`, `cleanupWorld`, `checkLedgerIntegrity`, `runSuite`).
- Her istek ayrı bir `npx supabase db query --linked` süreci; hepsi `pg_sleep_until` ile aynı ana kilitlenir. Çıktıdaki "zamanında başlayan: n/n" gerçekten eşzamanlı başladıklarını gösterir.
- Gerçek veri yazar: rastgele adlı bir test okulu ve kullanıcılar; sonunda (hata olsa bile) siler. Silmek için ledger koruma tetikleyicisi tek transaction içinde kapatılıp açılır. **Yalnızca geliştirme projesinde.**
- Yeni senaryo eklerken: `lib.mjs`'teki `cleanupWorld`, yeni tablolardaki test verisini de silecek şekilde güncellenmeli.
- Takılan istek 90 sn'de kesilir (`TIMEO`).
