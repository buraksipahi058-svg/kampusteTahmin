# Bölge: Para

Ledger (defter), bakiye, ekonomi ayarları, başlangıç SP'si, günlük giriş serisi, süperadmin para
işlemleri. Adım 2'de kuruldu; market ve görevler (Adım 9) buraya bağlanacak.

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
| `economy_settings` | Tek satır. Taslak değerler: başlangıç 1000 SP; günlük 50 + 10×(seri−1), en fazla 150; kilometre taşları 7→+200, 14→+500, 30→+1500; gün `Europe/Istanbul`. Adım 9'da kalibre edilecek. |

Görünürlük: kişi kendi ledger/bakiye/serisini, süperadmin hepsini görür. Ayarları herkes okur.

## Fonksiyonlar

İstemciye açık:
- `claim_daily_login()` → `(claimed, amount, current_streak, sp_balance)`. Günde bir kez; aynı gün tekrar çağrılırsa hata değil `claimed = false`. Profili yoksa `P0002`.
- `admin_grant(user_id, currency, amount, note)` — yalnızca süperadmin, yalnızca artı.
- `admin_adjust(user_id, currency, amount, note)` — yalnızca süperadmin, iki yönlü, negatife düşüremez.
  İkisinde de: gerekçe ≥ 3 karakter, tek işlemde ≤ 1.000.000 (`22003`), süperadmin kendine yapamaz.

İç: `private.balance_mismatches()` — önbellek ≠ ledger toplamı olan satırlar (boş dönmeli; testler ve
ileride admin paneli kullanır).

## Sıradaki işler

- **Adım 9 — market:** `market_purchase` sebebi ve `market_item` ref türü hazır. Satın alma = `post_ledger(-fiyat, 'market_purchase', 'market_item', item_id)` + envanter satırı, tek transaction'da.
- **Adım 9 — görevler:** `quest_reward` sebebi ve `quest` ref türü hazır. SSP yalnızca resmi görevden/süperadminden gelir.
- XP / seviye henüz hiçbir yerde artmıyor (profiles'ta kolon var).
