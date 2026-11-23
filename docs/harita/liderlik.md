# Bölge: Liderlik ve istatistik

Okulun haftalık ve tüm zamanlar sıralaması, kişisel istatistik, admin okul özeti. Adım 10'da kuruldu.
Kurallar: KARARLAR "Liderlik ve istatistik". Genel veritabanı kalıpları: [veritabani.md](veritabani.md).

Kod: `supabase/migrations/20261122133546_liderlik_istatistik.sql`. Testler: `10_liderlik.test.sql` (42).

## Ölçütler

"Tahmin" = düello dışı her bahis (resmi, sosyal, günün tahmini). Yalnızca **sonuçlanmış** bahisler sayılır
(iptal / açık / itiraz penceresindeki sayılmaz); dönem bahsin `settled_at`'ına göre (hafta pazartesi, İstanbul).

| `leaderboard_metric` | Değer | Kim girer |
|---|---|---|
| `hit_rate` | doğru / tahmin (0–1); doğru = seçilen seçenek kazandı | en az `leaderboard_min_predictions_week` (5) / `_all` (20) tahmin; eşitlikte çok tahmini olan önde |
| `sp_profit` | net SP (ödeme − yatırım), **düello dahil** | net > 0 |
| `ssp_profit` | net SSP (resmi bahis) | net > 0 |
| `best_streak` | art arda en uzun doğru tahmin (sıra: `settled_at`, bahis id) | en az bir doğru |

Kazanan tarafa kimse yatırmadığı için iade alan **yanlış** bilmiş sayılır; herkes doğru tarafta olup kazanç çıkmayan
**doğru** sayılır. Eşit değerler aynı sırayı paylaşır (`rank()`). "En çok bahis yapan" ölçütü bilerek yok (MIMARI §11).

## Tablolar

| Tablo | Not |
|---|---|
| `leaderboard_snapshots` | (okul, `period` week / all_time, `period_start` = pazartesi ya da null, ölçüt, kişi) başına bir satır: `rank`, `value`, `sample`, `computed_at`. Görür: kendi okulunun öğrencileri, o okulda `analitik_gor` sahibi, süperadmin. İstemci yazamaz. |
| `private.leaderboard_runs` | Hangi okul / dönem ne zaman hesaplandı (satırı olmayan sıralama için de). |

## Hesaplama

- `private.refresh_leaderboards()` — **pg_cron** `kampusbet_liderlik` her 10 dakikada; her okul için bu hafta ve tüm
  zamanlar baştan yazılır. Geçen hafta, bitişinden sonra bir kez daha hesaplanır, sonra **donar** (bir daha yazılmaz).
  Danışma kilidiyle iki hesaplama çakışmaz.
- Yardımcılar: `private.week_bounds(n)` (n hafta önceki haftanın günü / başı / sonu), `private.settled_wagers(okul?, kişi?, from, to)`,
  `private.store_leaderboard(...)`.

## İstemci fonksiyonları

- `get_leaderboard(metric, period, weeks_ago = 0, school_id = null, limit = 50)` — ilk N + listede yoksa çağıranın
  satırı; ad, soyad, seviye, kuşanılmış unvan / rozet / çerçeve / isim rengi, `computed_at`. Başka okul için `analitik_gor`
  (yoksa `P0002`); `weeks_ago` 0–52, `limit` 1–100 (`23514`).
- Güvenlik kontrolü 2: okul maili doğrulanmamış öğrenci kendi okulunun sıralamasını göremez (`KB002`; geçerli
  tanım `20261122223007_guvenlik_duzeltmeleri.sql`); `leaderboard_snapshots` RLS'i de aynı (`current_school_id`).
- `my_stats()` — tüm zamanlar, istek anında: tahmin, doğru, net SP / SSP, şu anki ve en iyi seri, düello oyun /
  galibiyet, sonucu bekleyen yatırım, bu haftaki sıralar (isabet, kazanç, seri; son hesaplamadan).
- `school_stats(school_id)` — admin, `analitik_gor` / süperadmin: üye, doğrulanmış, bu hafta bahse katılan / yatırım /
  yatırılan SP-SSP, açık bahis, açık itiraz, bu hafta görev ödülü ve market satışı.

## Ekranlar

- Mobil: Liderlik sekmesi (`lib/leaderboard/`; satıra dokununca kişinin profili `/kisi/:id`), Profil'de "İstatistiklerim" kartı ve `/gecmis` (geçmiş bahisler). [mobil](mobil.md)
- Admin: `/istatistik` (okul özeti + sıralama tablosu). [admin](admin.md)
- Silinen hesaplar sıralamaya girmez (`private.settled_wagers` süzer, Adım 11); silinince satırları hemen silinir.
- Sıralamadan çıkan (gizli) kişi sıralamaya girmez (`store_leaderboard` süzer, `get_leaderboard` göstermez; Adım 14);
  gizlenince satırları hemen silinir, açınca sonraki hesaplamada döner. Mobil Liderlik'te "Sıralamalarda gizlisin" notu.
  [guvenlik](guvenlik.md)
