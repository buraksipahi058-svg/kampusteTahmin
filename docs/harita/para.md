# Bölge: Para

Ledger (defter), bakiye, ekonomi ayarları, başlangıç SP'si, günlük giriş serisi, süperadmin para
işlemleri. Adım 2'de kuruldu; Adım 9'da görevler ve kozmetik market eklendi.

Kod: `supabase/migrations/20261020151007_para_cekirdegi.sql`.
Testler: `02_para_cekirdegi.test.sql` (47), eşzamanlılık `supabase/tests/concurrency/para.mjs` (4 senaryo).

## Altın kural

**Bakiye yalnızca `private.post_ledger` ile değişir.** Başka hiçbir kod `balances` ya da
`ledger_entries`'e yazmaz. Kullanıcılar arası transfer fonksiyonu yoktur ve yazılmaz (KARARLAR).

`private.post_ledger(user_id, currency, amount, reason, ref_type?, ref_id?, actor_id?, note?) → yeni bakiye`
1. `balances` satırını `FOR UPDATE` ile kilitler,
2. yeni bakiyeyi hesaplar; negatifse `KB001`,
3. bakiyeyi günceller ve ledger'a `balance_after` ile yazar.
Çağıranın transaction'ında çalışır. İstemci çağıramaz (yalnızca security definer RPC'ler).

## Tablolar

| Tablo | Not |
|---|---|
| `ledger_entries` | Yalnızca eklenir. İşaret kuralı: `bet_stake`, `market_purchase` eksi; `admin_adjust` iki yönlü; diğerleri artı. `signup_bonus` / `daily_login` yalnızca SP. `admin_*` için `actor_id` + `note` zorunlu. Başlangıç SP'si kişi başı bir (benzersiz indeks). Bahis kayıtları `ref_type = 'wager'`, her yatırıma tek yatırma + tek ödeme/iade (Adım 3 indeksleri). |
| `balances` | Önbellek: `sp_balance`, `ssp_balance` (≥ 0). Profil açılınca oluşur. |
| `login_streaks` | `current_streak`, `longest_streak`, `last_login_date`. |
| `economy_settings` | Tek satır. Taslak değerler: başlangıç 1000 SP; günlük 50 + 10×(seri−1), en fazla 150; kilometre taşları 7→+200, 14→+500, 30→+1500; gün `Europe/Istanbul`. Görev ödülleri ve market fiyatlarıyla birlikte taslak (KARARLAR), kullanıcı kalibre edecek. |

Görünürlük: kişi kendi ledger/bakiye/serisini, süperadmin hepsini görür. Ayarları herkes okur.

## Fonksiyonlar

İstemciye açık:
- `claim_daily_login()` → `(claimed, amount, current_streak, sp_balance)`. Günde bir kez; aynı gün tekrar çağrılırsa hata değil `claimed = false`. Profili yoksa `P0002`.
- `admin_grant(user_id, currency, amount, note)` — yalnızca süperadmin, yalnızca artı.
- `admin_adjust(user_id, currency, amount, note)` — yalnızca süperadmin, iki yönlü, negatife düşüremez.
  İkisinde de: gerekçe ≥ 3 karakter, tek işlemde ≤ 1.000.000 (`22003`), süperadmin kendine yapamaz.

İç: `private.balance_mismatches()` — önbellek ≠ ledger toplamı olan satırlar (boş dönmeli; testler ve
ileride admin paneli kullanır).

## Görevler ve market (Adım 9)

Kod: `20261122114042_gorevler_market.sql` (+ `..115132_market_sahip_gorunurlugu.sql`). Testler: `09_gorevler_market.test.sql` (72),
`para.mjs` senaryo 4-5 (eşzamanlı ödül ve satın alma). Kurallar: KARARLAR "Görevler", "Market".

| Tablo | Not |
|---|---|
| `quests` | `school_id` (null = tüm okullar), `period` (`daily` / `weekly` / `seasonal`), `action` (`wager`, `prediction`, `duel`, `social_bet`, `win`), `target`, ödül (`reward_currency`, `reward_amount` 1–1000), görünme aralığı `starts_at` / `ends_at` (sezonlukta zorunlu, dönemin kendisi), `active`. |
| `quest_claims` | Verilen ödüller, birincil anahtar (kişi, görev, dönem başı). **Yalnızca eklenir.** Kişi kendininkini görür. |
| `market_items` | `category` (`title`, `badge`, `frame`, `name_color`), `icon` (emoji) / `color` (#RRGGBB; çerçeve ve isim renginde zorunlu), `price` + `currency`, satış aralığı, `active`. Görür: okulun / genel satıştakiler + sahibi olduğu + okul arkadaşının kuşandığı. |
| `user_inventory` | Kişi başı ürün başı bir satır; `category` kopyası ile kategori başına tek `equipped` (benzersiz kısmi indeks). Kişi kendininkini, okul arkadaşları kuşanılmışları görür. |

- İlerleme: `private.quest_progress(user, action, from, to)` kayıtlardan sayar; dönem `private.quest_window(quest)` (gün `economy_settings.day_timezone`, hafta pazartesi). `win` düello kazancını da sayar, `wager` düelloyu saymaz.
- İstemci: `my_quests()` → görev + ilerleme (hedefle sınırlı) + `claimed` + dönem sonu; `claim_quest_reward(quest)` → (para, tutar, bakiye), tamamlanmadıysa `KB019`, alındıysa `KB020`. `purchase_market_item(item)` → bakiye; satışta değilse `KB021`, zaten varsa `KB022`, para yetmezse `KB001` (envanter satırı da geri alınır). `set_item_equipped(item, bool)`.
- Yönetim: `save_quest(...)` (`gorev_yonet`; genel ve SSP ödül süperadmin), `save_market_item(...)` (`market_yonet`; genel süperadmin; tür değişmez). İkisi de `admin_audit_log`'a yazar.
- Örnek veri: `seed.sql`'de 5 genel görev (`30000000-...`) ve 8 genel ürün (`40000000-...`).

## XP ve seviye

Kod: `20261122145831_xp_seviye.sql`. Testler: `11_xp_seviye.test.sql` (37); eşzamanlılık testleri her senaryoda
profildeki XP = olayların toplamı kontrolünü de yapar. Kurallar: KARARLAR "XP ve seviye".

XP paradan ayrıdır, ledger'a girmez. **Tek gerçek `xp_events`** (yalnızca eklenir): `reason` (`daily_login`, `quest`,
`correct_pick`), `amount`, kaynak (`ledger_entry_id` ya da `wager_id`, her kaynak bir kez), `xp_after`. Kişi kendininkini,
süperadmin hepsini görür. `profiles.xp` / `level` önbellektir. Sonradan eklenen nedenler: `achievement`, `campus_task`,
`word_puzzle` (kampüs kelimesi: ledger `word_reward` yalnızca SP, XP denemedeki `reward_xp`'den; [kelime](kelime.md)).

- `private.award_xp(user, reason, amount, ledger_entry_id?, wager_id?)` → verilen XP: profili kilitler, doğru tahminde
  günlük sınırı (`xp_daily_pick_cap`) uygular, olayı yazar, önbelleği günceller. Tekrar kaynakta 0 döner.
- Tetikleyiciler (para fonksiyonlarına dokunmadan): `ledger_entries` eklemesi — `daily_login` → `xp_daily_login`,
  `quest_reward` → `quests.reward_xp`; `bets` durumu `settled` olunca kazanan seçeneğe yatıranlar → `xp_correct_pick`.
- Seviye: `private.xp_for_level(L)` = `xp_level_step` × L × (L − 1) / 2, `private.level_for_xp(xp)`. Adım değişirse
  mevcut seviyeler kendiliğinden değişmez: `update public.profiles set level = private.level_for_xp(xp);`.
- İstemci: `my_progress()` → xp, seviye, seviyenin ve sonrakinin başladığı XP, bugünkü tahmin XP'si. Market ürününde
  `min_level`; yetmeyen satın alma `KB023`. `my_quests` görevin `reward_xp`'sini döner; `save_quest` (`p_reward_xp`) ve
  `save_market_item` (`p_min_level`) yeni parametreleri sonda, varsayılanlı.

## Başarımlar ve günlük ödül takvimi (Adım 16)

Kod: `20261122210722_basarim_degerleri.sql` (enum), `20261122210724_basarimlar_gunluk_odul.sql`. Test: `17_basarimlar.test.sql` (32), `para.mjs` 4c. Kurallar: KARARLAR "Başarımlar ve günlük ödül takvimi".

- `achievements`: anahtar, kategori (`achievement_category`), ad, açıklama, simge, ölçüt, hedef, kademe (1 bronz, 2 gümüş, 3 altın), `reward_sp` (≥ 1), `reward_xp`, `hidden`, `sort`, `active`. Herkes (giriş yapan) okur; katalog migration'da (25 başarım), admin'den düzenleme yok.
- `achievement_unlocks` (yalnızca eklenir): kişi + başarım, o anki ödül, `unlocked_at`. Görür: kendisi, okul arkadaşları (profilde rozet), süperadmin.
- Ölçütler (`private.achievement_metrics(kişi)`, tüm zamanlar): predictions, correct, best_streak (sonuçlanmış tahminler, `settled_wagers`), duels_played, duels_won, perfect_duels (tüm sorular doğru), social_created (açtığı sonuçlanmış sosyal), fair_referee (hakemliğinde itirazla değişmeyen sonuçlanmış sosyal), login_streak (en uzun), sp_profit (net SP), level, items_owned, quests_claimed, verified, official_wins (SSP kazancı), underdog_wins (havuzlu bahiste kazanan taraf havuzun %20'sinden azken kazanmak).
- `my_achievements()` → anahtar, kategori, ad, açıklama, simge, kademe, ölçüt, hedef, ilerleme (hedefle sınırlı), ödül, gizli, `unlocked_at`, `claimable`, `school_rate` (okulunda açanların oranı). Gizli ve kazanılmamışta ad / açıklama / simge / ölçüt gizlenir. Silinmiş: `P0002`.
- `claim_achievement(anahtar)` → (SP, XP, bakiye): hedefe ulaşılmadıysa `KB027`, ikinci kez `KB028` (eşzamanlı istekte birincil anahtar bekletir), yok / kapalı `P0002`. SP `achievement_reward` / `achievement` ref ile ledger'a; XP `xp_on_ledger_entry` tetikleyicisiyle (`xp_reason.achievement`).
- `daily_login_calendar()` → 7 satır (gün, ödül, bonus, alındı, bugün): serinin içinde bulunulan 7 günlük dilim; bugün alınmadıysa "bugün" dün alındıysa seri + 1, değilse 1. Tutar `claim_daily_login` formülüyle aynı.
- Mobil: `lib/achievements/` (`/basarimlar`, Profil'de kart + hazır ödül rozeti), `lib/wallet/daily_reward_sheet.dart` (açılışta kişi başına bir kez, üst çubukta hediye simgesi; SP ve XP yazar). Başarıma yeni ulaşılınca ya da açılışta bekleyen ödül varsa alt çubukta haber + "Gör" (`newAchievementMessage`, `home_shell.dart`). [mobil](mobil.md)
- Yönetim: `save_achievement(id?, anahtar, kategori, ad, açıklama, simge, ölçüt, hedef, kademe, SP, XP, gizli, sıra, açık)` yalnızca süperadmin (`42501`); anahtar değişmez (`23514`), bilinmeyen ölçüt / kademe `23514`, tekrar anahtar `23505`, olmayan `P0002`; denetim kaydı `achievement_save`. Admin `/basarimlar` (liste, kazanan sayısı, ekle, `[id]` düzenle, aç / kapat). Test: `18_basarim_yonetimi.test.sql` (15).

## Sıradaki işler

- Seviyeyle özellik açma (ör. sosyal bahis açmak) yok; yalnızca market ürünü açılır. Geriye dönük XP verilmedi.
