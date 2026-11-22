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

## Sıradaki işler

- XP / seviye henüz hiçbir yerde artmıyor (profiles'ta kolon var); görevler XP vermiyor.
