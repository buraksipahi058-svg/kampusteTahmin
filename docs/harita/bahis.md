# Bölge: Bahis

Türlerden bağımsız bahis çekirdeği (Adım 3) ve üzerine gelecek türler: resmi SSP (Adım 6),
sosyal havuz (Adım 7), mini oyun (Adım 8).

Kod: `supabase/migrations/20261020160619_bahis_cekirdegi.sql`, `20261122082914_resmi_bahisler.sql`
(`create_bet`, `settle_bet`, `place_wager`'ın **geçerli tanımları bu ikincisinde**).
Testler: `03_bahis_cekirdegi.test.sql` (61), `05_resmi_bahis.test.sql` (37), eşzamanlılık `supabase/tests/concurrency/bahis.mjs` (5 senaryo).

## Tablolar

| Tablo | Not |
|---|---|
| `bets` | `type` → para birimi ve sonuçlandırma kipi sabit: `ssp_official` = SSP + admin; `sp_minigame` = SP + auto; `sp_social` = SP + referee (`referee_id` zorunlu). `odds_mode`: `pool` ya da `fixed` (yalnızca resmi bahis `fixed` olabilir). Kapsam v1'de `school` (okul kümesi) ya da `private` (okul dışı küme). `pool_total`, `min_stake`, `max_stake`, `opens_at`, `locks_at`, `settled_*`, `cancelled_*`, `cancel_reason`. |
| `bet_options` | 2–10 seçenek, `position`, `pool_amount`, `odds` (sabit oranda 1,01–20,00), `is_winner` (sonuçlanınca). |
| `wagers` | Kişi başı bahis başına bir yatırım (benzersiz). `odds`: yatırım anındaki oran (sabit oranda). `payout`: sonuçlanınca yazılır (kaybeden 0, iade = yatırılan). |

Görünürlük: bahis ve seçenekleri kümesinin üyelerine (okul kapsamında okulun tüm öğrencileri);
bireysel yatırımlar yalnızca sahibine ve süperadmine. Havuz toplamları açık.

## Durumlar

`open` → (`locks_at` geçer ya da `lock_bet`) → `locked` → `settle_bet` → `settled`
Her an (sonuçlanmadan önce) → `cancel_bet` → `cancelled`.
`settling` Adım 7'deki itiraz penceresi için ayrıldı, henüz kullanılmıyor.

## Fonksiyonlar

İstemciye açık:
- `place_wager(bet_id, option_id, amount) → wagers` — doğrulanmış okul maili (`KB002`), bahis görünür olmalı (`P0002`), açık ve süresi geçmemiş (`KB003`), hakem / resmi bahsi açan / resmi bahsi sonuçlandırabilecek olan (`resmi_bahis_kapat`, süperadmin) yatıramaz (`42501`), tutar sınırlar içinde (`23514`), tek yatırım (`KB004`), bakiye (`KB001`). Bahis satırını kilitler.
- Resmi bahis yönetimi (admin paneli çağırır; her biri `admin_audit_log`'a yazar):
  `create_official_bet(school_id, title, description, options[], odds[], locks_at, max_stake?)` (`resmi_bahis_ac`),
  `lock_official_bet(bet_id)`, `settle_official_bet(bet_id, winning_option_id)`, `cancel_official_bet(bet_id, reason)` (`resmi_bahis_kapat`).
  Resmi olmayan bahiste `P0002`. Yetki kontrolü `private.official_bet_for(bet_id, key)`.

İç (`private`, yetki kontrolü yok — çağıran RPC yapacak):
- `create_bet(creator, cluster, type, scope, title, description, options[], locks_at, referee?, min_stake?, max_stake?, odds[]?) → bet_id` — açanın okul maili doğrulanmış olmalı; `odds` verilirse sabit oran.
- `lock_bet(bet_id)` — yalnızca `open` iken.
- `settle_bet(bet_id, winning_option_id, actor_id)` — yalnızca kilitli/süresi geçmiş (`KB005`), bir kez (`KB006`).
- `cancel_bet(bet_id, reason, actor_id)` — gerekçe zorunlu, herkese iade.

## Pari-mutuel dağıtım

Kesinti yok. Kazanan havuzu `W`, toplam havuz `T`: her kazanana `floor(yatırım × T / W)`; kalan
`T − Σ` SP, kesirli payı en büyük olandan başlayarak 1'er (eşitlikte önce yatıran). Böylece `Σ ödeme = T`.
`W = 0` ise herkese iade (`bet_refund`). Ödemeler `user_id` sırasıyla yazılır (kilitlenme önlemi).

## Sabit oran (resmi bahis, Adım 6)

Kazanan `floor(yatırım × wagers.odds)`, kaybeden 0; kazanan yoksa ödeme de yok. Ödeme yeni SSP'dir
(sistem kasa), bu yüzden "dağıtılan = havuz" kuralı yalnızca `pool` bahislerinde geçerlidir.
Panel ve mobil "kazanırsa ödenecek" tutarını bilgi için `floor(havuz × oran)` / `floor(yatırım × oran)` diye gösterir.

## Sıradaki işler

- Resmi bahis kalan: sabit oran mı havuz mu kararı "sonra tekrar bakılacak" (KARARLAR). Oran sonradan değiştirilemiyor (yalnızca açarken).
- **Adım 7 — sosyal havuz:** doğrulanmış öğrenci açar (varsayılan hakem kendisi), düşük `max_stake`, hakem sonucu girer → `settling` + itiraz penceresi → itiraz yoksa ödeme; itirazda `kullanici_bahsi_denetle` izni olan moderatör sonuç belirler ya da iptal + iade. Hakem itibar puanı. Kapanış ve itiraz süresi için zamanlanmış iş (pg_cron). Moderatörün özel grup bahislerini görmesi için `bets` RLS'ine ek gerekecek.
- **Adım 8 — mini oyun:** `sp_minigame` + `auto`; sonuç sunucuda belirlenir (trivia cevabı istemciye gitmez).
- Düello/sosyal havuzla bilerek kaybedip SP aktarma riski: düşük limit + aynı kişilerin sık eşleşmesini izleme.
