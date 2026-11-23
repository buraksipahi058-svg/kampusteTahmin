# Bölge: Bahis

Türlerden bağımsız bahis çekirdeği (Adım 3) ve üzerine gelecek türler: resmi SSP (Adım 6),
sosyal havuz (Adım 7), mini oyun (Adım 8).

Kod: `supabase/migrations/20261020160619_bahis_cekirdegi.sql`, `20261122082914_resmi_bahisler.sql`
(`create_bet`, `settle_bet`'in **geçerli tanımları bu ikincisinde**; `place_wager`'ınki `20261122105335_gunun_tahmini.sql`'de).
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

## Sosyal havuz (Adım 7)

Kod: `20261122085500_sosyal_havuz.sql` (+ `..090045` `create_social_bet` kontrol sırası, `..090304` belirsiz ilişki
düzeltmesi). Testler: `06_sosyal_havuz.test.sql` (54).

- `bets` ek kolonlar: `proposed_option_id` (hakemin sonucu, yabancı anahtar **yok** — olursa `bet_options(...)` gömmesi PGRST201 ile belirsizleşir), `result_submitted_at`, `dispute_until`. `profiles.referee_strikes` (ihtar).
- `bet_disputes`: kişi başı bahis başına bir itiraz; `open` → `resolved` (`confirmed` / `changed` / `cancelled`). Görür: itiraz eden, bahsin hakemi, moderatör.
- Ayarlar (`economy_settings`, taslak): `social_max_stake_sp` 100, `social_dispute_hours` 12, `social_result_deadline_days` 7, `referee_strike_limit` 3.
- Fonksiyonlar (istemci): `create_social_bet(cluster, title, description, options[], locks_at, referee?, max_stake?)` (doğrulanmış, kümenin üyesi; hakem varsayılan kendisi, kümenin doğrulanmış üyesi olmalı; ihtar sınırı `KB014`; kapanış ≤ 30 gün), `submit_social_result(bet, option)` (yalnızca hakem, bir kez `KB015`; yatırımlar kapanır), `dispute_social_result(bet, reason)` (yalnızca yatırım yapan, pencere içinde `KB016`), `cancel_social_bet(bet, reason)` (açan yatırım yokken; moderatör her zaman), `resolve_social_dispute(bet, decision, note, option?)` (`kullanici_bahsi_denetle`; hakem/katılımcı karar veremez; açık itiraz yoksa `KB017`; değiştirme/iptal hakeme ihtar).
- İç: `private.process_social_bets()` — **pg_cron** `kampusbet_sosyal_bahisler` her 5 dakikada çağırır: itiraz penceresi dolan ve açık itirazı olmayanları kesinleştirir (ödeme hakem adına), kapanıştan 7 gün sonra sonuç girilmemişleri iptal + iade eder ve hakeme ihtar yazar. Kayıtlar: `cron.job_run_details`.
- Moderatör, `bets` RLS'indeki ek koşulla okulundaki özel grup bahislerini de görür.
- Grup oluşturma / gruba katılma henüz yok: sosyal bahis pratikte okul geneli.

## Mini oyun: trivia düellosu (Adım 8)

Kod: `20261122092401_trivia_izni.sql` (izin değeri `trivia_yonet`), `20261122092403_trivia_duellosu.sql`.
Testler: `07_trivia_duellosu.test.sql` (45). Kurallar: KARARLAR "Mini oyun: trivia düellosu" (varsayılan, onay bekliyor).

- Düello = `sp_minigame` bahsi (`settlement_mode = 'auto'`); seçenek 1 "Meydan okuyan", 2 "Rakip"; her oyuncu kendi seçeneğine eşit tutar yatırır (`private.stake_wager`), kazananın seçeneği kazanır. **`place_wager` düelloya kapalı** (`42501`).
- Tablolar: `trivia_questions` (`correct_index` öğrenciye hiç görünmez; okuyabilen yalnızca `trivia_yonet` / süperadmin; `school_id` null = genel), `trivia_duels` (okul görür; `question_ids`, süreler), `trivia_duel_plays` (kişi kendi oyununu, düello bitince ikisi birbirininkini görür).
- Ayarlar: `trivia_question_count` 5, `trivia_seconds_per_question` 15, `duel_max_stake_sp` 100, `duel_accept_hours` 24, `duel_play_hours` 24.
- İstemci: `create_trivia_duel(stake, invited?)` → bet_id (soru yönetebilen oynayamaz), `accept_trivia_duel(bet)` (`KB018`), `start_trivia_duel(bet)` → (soru_no, soru, şıklar, kalan_sn) — ilk çağrıda süre başlar, tekrar çağrı aynı soruları verir; `submit_trivia_answers(bet, answers smallint[])` → (puan, geç) — süre +10 sn payı aşılırsa 0. İkisi de gönderince sonuçlanır.
- Kazanan: çok doğru, eşitlikte az süre (sunucu ölçer); oynamayan 0 puan + en kötü süre; tam eşitlikte iptal + iade.
- Yönetim: `save_trivia_question(id?, school?, soru, şıklar[], doğru, kategori?, aktif?)`.
- **pg_cron** `kampusbet_trivia_duellolari` 5 dakikada bir `private.process_trivia_duels()`: kabul süresi dolanı iade, oynama süresi dolanı sonuçlandırır.
- Örnek veri: `seed.sql`'de 16 genel kültür sorusu.

## Mini oyun: günün tahmini (Adım 8)

Kod: `20261122105335_gunun_tahmini.sql`. Testler: `08_gunun_tahmini.test.sql` (45). Kurallar: KARARLAR "Mini oyun: günün tahmini".
v1'de başka mini oyun yok (reflex / şans oyunları kullanıcı kararıyla çıkarıldı).

- Günün tahmini = `sp_minigame` + **`settlement_mode = 'admin'`** (düello `auto`). Ayrı tablo yok; istemciler bu iki kolonla süzer. `bets_settlement_by_type` kısıtı mini oyunda `auto` ya da `admin`'e izin verir.
- Seçenekler hep "Evet" / "Hayır", havuz (pari-mutuel). Ayarlar: `daily_max_stake_sp` 100, `daily_result_deadline_days` 3.
- `place_wager` artık yalnızca **`auto`** mini oyunu reddeder; "sonucu belirleyen yatırım yapamaz" kuralı `settlement_mode = 'admin'` olan her bahiste (resmi + günün tahmini): açan ve `resmi_bahis_kapat` sahibi.
- Yönetim (admin paneli, `admin_audit_log`'a yazar): `create_daily_prediction(school, question, locks_at, description?)` (`resmi_bahis_ac`, kapanış ≤ 7 gün), `settle_daily_prediction(bet, option)`, `cancel_daily_prediction(bet, reason)` (`resmi_bahis_kapat`). Yetki kontrolü `private.daily_prediction_for`. Resmi bahis fonksiyonları günün tahminine, bunlar da resmi bahse / düelloya `P0002` verir.
- **pg_cron** `kampusbet_gunun_tahmini` saatte bir `private.process_daily_predictions()`: kapanıştan 3 gün sonra hâlâ sonuçsuz olanı iptal + iade.

## Mobil eksikler (Adım 15)

Kod: `20261122203439_mobil_eksikler.sql`. Test: `16_mobil_eksikler.test.sql` (17).

- `search_schoolmates(sorgu)` → (kişi, ad, soyad, bölüm, seviye, `can_referee`): okulun okul maili doğrulanmış öğrencileri; kendisi, silinmiş, yasaklı ve başka okul gelmez; 2–50 karakter (`23514`), en fazla 20, ad + soyad içinde büyük / küçük harf duyarsız (`%` `_` düz aranır). `can_referee` = ihtar sınırında değil. Mobil kişi seçme penceresi (`lib/people/person_picker.dart`) meydan okumada "Birine" ve sosyal bahiste "Hakem" için.
- `trivia_duel_review(bet)` → (soru no, soru, şıklar, doğru şık, kişinin cevabı, rakibin cevabı): yalnızca düello bittiyse (`settled` / `cancelled`), düellonun oyuncusuna ve yalnızca oynamışsa (soruları görmemiş olana `P0002`). Mobil: biten düelloda "Cevapları gör" → `/duello/:id/cevaplar`.

## Sıradaki işler

- Grup oluşturma ve davetle katılma (özel kapsamlı sosyal bahisler için).
- Resmi bahis kalan: sabit oran mı havuz mu kararı "sonra tekrar bakılacak" (KARARLAR). Oran açık bahiste değiştirilebilir (Adım 13).
- Düello cevapları gösterildiği için soru havuzu büyümeli (seed'de 16 genel soru).
- Düello/sosyal havuzla bilerek kaybedip SP aktarma riski: düşük limit + aynı kişilerin sık eşleşmesini izleme.
