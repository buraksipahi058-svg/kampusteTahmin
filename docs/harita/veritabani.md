# Bölge: Veritabanı (genel)

Herhangi bir migration, RLS politikası ya da SQL fonksiyonu yazmadan önce bu sayfa okunur.
Konu bölgeleri: [kimlik.md](kimlik.md), [para.md](para.md), [bahis.md](bahis.md), [liderlik.md](liderlik.md), [guvenlik.md](guvenlik.md). Testler: [testler.md](testler.md).

## Migration'lar (sırayla)

| Dosya | Adım | İçerik |
|---|---|---|
| `20261020145105_kumeler_profiller_yetkiler.sql` | 1 | `private` şeması, kümeler, okul alan adları, profiller, gizli profil, üyelikler, yetkiler, denetim kaydı, RLS yardımcıları, `create_profile`, `grant/revoke_permission` |
| `20261020145832_kume_ust_kume_hatasi.sql` | 1 | `private.clusters_set_school` düzeltmesi (anlaşılır hata) |
| `20261020151007_para_cekirdegi.sql` | 2 | Ekonomi ayarları, ledger, bakiye, seri, `post_ledger`, `create_profile`'ın yeni hali (bakiye + başlangıç SP), `claim_daily_login`, `admin_grant/adjust` |
| `20261020160619_bahis_cekirdegi.sql` | 3 | Bahis, seçenek, yatırım, ledger'a bahis kısıtları, `create/lock/settle/cancel_bet`, `place_wager` |
| `20261122080714_okul_maili_dogrulama.sql` | 5 | `pg_net`, mail ayarları + geliştirme kutusu, kod kayıtları (private), `send_mail`, `request_student_email_code`, `confirm_student_email` |
| `20261122082914_resmi_bahisler.sql` | 6 | `odds_mode`, seçenek/yatırım oranı; `create_bet` (oranlı), `settle_bet` (sabit oran), `place_wager` (oran + sonuçlandırabilecek olan yatıramaz) yeniden; `create/lock/settle/cancel_official_bet` |
| `20261122085500_sosyal_havuz.sql` | 7 | `pg_cron` + 5 dakikalık iş, sosyal ayarlar, `referee_strikes`, bahiste hakem sonucu kolonları, `bet_disputes`, `bets` RLS'ine moderatör, sosyal bahis RPC'leri, `process_social_bets` |
| `20261122090045_sosyal_havuz_dogrulama_sirasi.sql` | 7 | `create_social_bet`: önce okul maili kontrolü (`KB002`) |
| `20261122090304_onerilen_secenek_iliskisi.sql` | 7 | `bets.proposed_option_id` yabancı anahtarı kaldırıldı (PostgREST gömme belirsizliği) |
| `20261122092401_trivia_izni.sql` | 8 | `permission_key`'e `trivia_yonet` (ayrı migration: yeni enum değeri aynı transaction'da kullanılamaz) |
| `20261122092403_trivia_duellosu.sql` | 8 | trivia ayarları, soru / düello / oyun tabloları, `stake_wager`, `place_wager` (mini oyuna kapalı), düello RPC'leri, `save_trivia_question`, pg_cron düello işi |
| `20261122114042_gorevler_market.sql` | 9 | görev / ödül / ürün / envanter tabloları ve RLS, ilerleme sayımı (`quest_window`, `quest_progress`), `my_quests`, `claim_quest_reward`, `purchase_market_item`, `set_item_equipped`, `save_quest`, `save_market_item` |
| `20261122115132_market_sahip_gorunurlugu.sql` | 9 | `market_items` RLS: sahip olunan ve okul arkadaşının kuşandığı ürün satışta olmasa da görünür |
| `20261122133546_liderlik_istatistik.sql` | 10 | sıralama ayarları, `leaderboard_snapshots` + RLS, `private.leaderboard_runs`, hesaplama (`week_bounds`, `settled_wagers`, `store_leaderboard`, `refresh_leaderboards`), `get_leaderboard`, `my_stats`, `school_stats`, 10 dakikalık pg_cron işi ([liderlik](liderlik.md)) |
| `20261122145831_xp_seviye.sql` | 10 | XP ayarları, `quests.reward_xp`, `market_items.min_level`, `xp_events` (yalnızca eklenir) + RLS, seviye eğrisi (`xp_for_level`, `level_for_xp`), `award_xp`, ledger ve bahis tetikleyicileri, `my_progress`; `purchase_market_item` (`KB023`), `my_quests`, `save_quest`, `save_market_item`, `get_leaderboard` yeniden ([para](para.md)) |
| `20261122152129_hesap_silme_guvenlik.sql` | 11 | denetim düzeltmeleri (tetikleyici fonksiyonu, kimlik dizileri, varsayılan yetkiler), `profiles.deleted_at`, `profiles_update_own` (silinmiş hariç), `settled_wagers` ve `school_stats` (silinmişleri saymaz), `delete_my_account` ([guvenlik](guvenlik.md)) |
| `20261122173731_qa_duzeltmeleri.sql` | 12 | kalite kontrolü: `current_school_id` / `is_verified` silinmişi saymaz, `request_student_email_code`, `award_xp`, `delete_my_account` (`FOR NO KEY UPDATE`, düello başlığı, Auth 100 yıl), `claim_quest_reward` (görev yöneten alamaz), `get_leaderboard` (silinmiş gösterilmez) |
| `20261122182015_yonetim_guvenlik.sql` | 13 | `profiles.banned_at`, `guard.check_request` + `pgrst.db_pre_request` (istek bekçisi), `set_user_ban`, `reset_referee_strikes`, `update_official_bet_odds` ([guvenlik](guvenlik.md)) |
| `20261122182256_yasak_gerekcesi.sql` | 13 | yasak gerekçesi profilden kaldırıldı (okula açıktı), yalnızca denetim kaydında; `set_user_ban` yeniden |
| `20261122200659_gizlilik.sql` | 14 | `profile_private.leaderboard_hidden` + `set_leaderboard_hidden`, `store_leaderboard` / `get_leaderboard` (gizliyi saymaz), `export_my_data`, `economy_settings.api_write_limit_per_minute`, `private.request_log` (unlogged) + `guard.check_request` (istek sınırı, `KB026`), 10 dakikalık `kampusbet_istek_sayaci` temizliği ([guvenlik](guvenlik.md)) |
| `20261122203439_mobil_eksikler.sql` | 15 | `search_schoolmates` (meydan okuma / hakem için doğrulanmış okul arkadaşı arama), `trivia_duel_review` (bitmiş düellonun cevapları, yalnızca oynamış oyuncuya) ([bahis](bahis.md)) |
| `20261122210722_basarim_degerleri.sql` | 16 | enum değerleri: `ledger_reason.achievement_reward`, `ledger_ref_type.achievement`, `xp_reason.achievement` (ayrı migration: yeni enum değeri aynı transaction'da kullanılamaz) |
| `20261122210724_basarimlar_gunluk_odul.sql` | 16 | `achievements` (katalog, 25 başarım) + `achievement_unlocks` (yalnızca eklenir) + RLS, `private.achievement_metrics`, `my_achievements`, `claim_achievement`, `daily_login_calendar`; `xp_on_ledger_entry` ve tetikleyicisi, `xp_events_source` ve `ledger_sp_only_rewards` kısıtları yeniden ([para](para.md)) |
| `20261122212408_basarim_yonetimi.sql` | 16 | `save_achievement` (yalnızca süperadmin; anahtar değişmez, denetim kaydı `achievement_save`) |
| `20261122214819_bildirimler.sql` | 17 | `notifications` + RLS, bildirim tetikleyicileri (bahis, itiraz, düello, profil, yönetici para), `process_notifications` + 5 dakikalık iş, `mark_notifications_read` ([kampus](kampus.md)) |
| `20261122215319_kampus_gorevi_degerleri.sql` | 17a | enum: `kampus_gorevi_yonet`, `campus_task_reward`, `ledger_ref_type.campus_task`, `xp_reason.campus_task` |
| `20261122215322_kampus_gorevleri.sql` | 17a | `campus_tasks`, `private.campus_task_secrets`, `campus_task_submissions` + RLS, QR kodu (HMAC), `save_campus_task`, `reset_campus_task_qr`, `campus_task_qr`, `my_campus_tasks`, `submit_campus_task_qr`; `xp_on_ledger_entry` ve `achievement_metrics` yeniden, `campus_tasks` başarımları ([kampus](kampus.md)) |
| `20261122221347_kampus_fotograf.sql` | 17b | `campus-proofs` depolama alanı + `storage.objects` politikaları, `private.storage_settings`, `private.storage_delete` (pg_net), `submit_campus_task_photo`, `review_campus_submission`, `process_campus_submissions` + saatlik iş, bildirim türleri, `notify_profile` yeniden (silinince fotoğraf) ([kampus](kampus.md)) |
| `20261122223007_guvenlik_duzeltmeleri.sql` | G2 | Güvenlik kontrolü 2 ([guvenlik](guvenlik.md) sonu): `export_my_data` biçim 2, `current_school_id` / `my_cluster_ids` doğrulanmışa, `get_leaderboard` (KB002), `profiles` kolon bazlı okuma (`banned_at` kapalı) + `banned_users`, `place_wager` (resmi_bahis_ac), kampüs görevi tavanı / günlük sınır (`check_campus_daily_limit`) / SSP yalnızca süperadmin / onay kenar durumları, depolama 1 MB + saatlik / günlük sınır, `trivia_duel_review` yalnızca sonuçlanmış, `achievements_select` gizli |
| `20261124074445_kelime_oyunu_degerleri.sql` | 19 | enum: `kelime_yonet`, `ledger_reason.word_reward`, `ledger_ref_type.word_puzzle`, `xp_reason.word_puzzle` |
| `20261124074448_kelime_oyunu.sql` | 19 | kelime ayarları, `word_puzzles` / `word_attempts` + RLS, `private.word_answers` / `word_dictionary`, yardımcılar, `ledger_sp_only_rewards` + `xp_events_source` + `xp_on_ledger_entry` (kelime ödülü), `my_word_puzzle`, `submit_word_guess`, `save/delete_word_puzzle`, `list_word_puzzles`, `export_my_data` sarmalayıcı ([kelime](kelime.md)) |
| `20261124074450_kelime_sozlugu.sql` | 19 | sözlük verisi (18.849 kelime; `supabase/sozluk/sozluk_migration.py` üretir) |
| `20261124084204_kelime_guvenlik_ipucu.sql` | G3 + 19 | Güvenlik kontrolü 3 ([guvenlik](guvenlik.md) sonu) ve ipucu: `word_hint_after`, `word_answers.hint`, `private.word_puzzle_viewers`, `word_puzzles` kolon bazlı okuma, `word_reward_blocked(bulmaca, okul)`, `word_puzzle_for_user`, `word_hint_visible`; `my_word_puzzle`, `submit_word_guess`, `save_word_puzzle` (+ipucu), `list_word_puzzles` yeniden ([kelime](kelime.md)) |
| `20261122105335_gunun_tahmini.sql` | 8 | günün tahmini ayarları, `bets_settlement_by_type` (mini oyunda `admin` de olur), `place_wager` (yalnızca `auto` mini oyuna kapalı; admin sonuçlandırmalıda açan / kapatan yatıramaz), `create/settle/cancel_daily_prediction`, saatlik pg_cron işi |

## Koda inmek gerekirse

Migration dosyalarını baştan okuma; aradığın tanımın satırını bul ve yalnızca orayı oku:

```bash
grep -n "function private.post_ledger" supabase/migrations/*.sql     # fonksiyon
grep -n "create table public.bets" supabase/migrations/*.sql         # tablo
grep -n "create policy" supabase/migrations/*.sql                    # tüm RLS politikaları
```

Aynı fonksiyon birden fazla migration'da tanımlıysa **en yeni dosyadaki** geçerlidir:

| Fonksiyon | Geçerli tanım | Eski tanım (okuma) |
|---|---|---|
| `public.create_profile` | `20261020151007_para_cekirdegi.sql` | `20261020145105_...` |
| `private.clusters_set_school` | `20261020145832_kume_ust_kume_hatasi.sql` | `20261020145105_...` |
| `private.create_bet`, `private.settle_bet` | `20261122082914_resmi_bahisler.sql` | `20261020160619_...` |
| `public.place_wager` | `20261122105335_gunun_tahmini.sql` | `20261122092403_...`, `20261122082914_...`, `20261020160619_...` |
| `public.create_social_bet` | `20261122090045_sosyal_havuz_dogrulama_sirasi.sql` | `20261122085500_...` |
| `public.purchase_market_item`, `my_quests`, `save_quest`, `save_market_item` | `20261122145831_xp_seviye.sql` | `20261122114042_...` |
| `public.get_leaderboard` | `20261122145831_xp_seviye.sql` | `20261122133546_...` |
| `private.settled_wagers`, `public.school_stats` | `20261122152129_hesap_silme_guvenlik.sql` | `20261122133546_...` |
| `private.current_school_id`, `private.is_verified`, `public.request_student_email_code`, `private.award_xp`, `public.delete_my_account`, `public.claim_quest_reward` | `20261122173731_qa_duzeltmeleri.sql` | önceki tanımlar |
| `public.get_leaderboard`, `private.store_leaderboard`, `guard.check_request` | `20261122200659_gizlilik.sql` | `20261122173731_...`, `20261122133546_...`, `20261122182015_...` |
| `private.xp_on_ledger_entry`, `public.export_my_data` (eski gövdesi `private.export_my_data_base`) | `20261124074448_kelime_oyunu.sql` | `20261122215322_...`, `20261122223007_...` |
| `public.my_word_puzzle`, `submit_word_guess`, `save_word_puzzle`, `list_word_puzzles` | `20261124084204_kelime_guvenlik_ipucu.sql` | `20261124074448_...` |

**İki tablo arasına ikinci bir yabancı anahtar ekleme:** PostgREST istemci sorgularında gömme
(`bets?select=...,bet_options(...)`) belirsizleşir (PGRST201) ve mobil/admin sorguları bozulur.
Gerekirse kontrolü fonksiyonda yap ya da istemcide `!kolon` ipucuyla göm.

Buluttaki gerçek durumu görmek daha ucuzsa: `npx supabase db query --linked "select pg_get_functiondef('public.place_wager'::regproc)"`.

`supabase/seed.sql`: tek okul — "Örnek Üniversitesi", id `10000000-0000-4000-8000-000000000001`, alan adı `ogr.ornek.edu.tr` (gerçek okul belli olunca değişecek).

## Kalıplar (yeni kod da böyle yazılır)

- **Şemalar:** `guard` yalnızca istek bekçisi (`check_request`; anonim ve giriş yapan çalıştırır, API'ye açık değil). `public` API'ye açık (tablolar, enum'lar, istemcinin çağırdığı RPC'ler). `private` API'ye kapalı (RLS yardımcıları, iç fonksiyonlar, tetikleyiciler).
- **Tablo yetkileri:** her yeni tabloda `revoke all ... from anon, authenticated;` sonra yalnızca `grant select ... to authenticated;`. İstemci hiçbir tabloya ekleme/silme yapamaz. Tek istisna: `profiles` için `grant update (first_name, last_name, department)`.
- **RLS:** her tabloda açık. Politikalarda `(select auth.uid())`, `(select private.is_superadmin())` gibi alt sorgu biçimi (her satırda tekrar çalışmasın). Kümeye göre görünürlük: `cluster_id in (select private.my_cluster_ids())`.
- **Varsayılan yetkiler (Adım 11):** postgres'in oluşturduğu yeni tablo, dizi ve fonksiyon istemcilere ve PUBLIC'e kapalı başlar. Tablo için `grant select`, RPC için `grant execute ... to authenticated` açıkça yazılır; RLS politikasında kullanılan yeni `private` yardımcısı da `authenticated`'a açılmalı ve `12_guvenlik` testindeki listeye eklenmeli.
- **Fonksiyonlar:** hepsi `set search_path = ''` ve tam nitelikli adlar (`public.x`, `private.y`). İstemci RPC'leri `security definer`; başta oturum (`auth.uid()`), sonra yetki, sonra girdi kontrolü. Her fonksiyonda `revoke execute ... from public, anon;` + gerekiyorsa `grant execute ... to authenticated;`. İç fonksiyonlarda yalnızca `revoke ... from public`.
- **Yalnızca eklenen tablolar:** `private.forbid_change()` tetikleyicisi (update/delete/truncate → `55000`). Şu an: `ledger_entries`, `admin_audit_log`, `quest_claims`, `xp_events`, `achievement_unlocks`. Bildirimler yalnızca eklenir + okundu işareti (`read_at`, RPC ile).
- **Metin kolonları:** `char_length` aralığı + `= btrim(...)` + kontrol karakteri yasağı (`!~ '[[:cntrl:]]'`).
- **Görünmeyen kayıt:** yetkisi olmayana "bulunamadı" (`P0002`) dönülür, "yetkin yok" değil (varlığı sızdırmamak için).
- **Kilit sırası:** bahis satırı → bakiyeler (`user_id` sırasıyla) → profil satırları (XP, `user_id` sırasıyla). Profil satırı **`FOR NO KEY UPDATE`** ile kilitlenir, asla `FOR UPDATE` değil: profile yabancı anahtarla bağlı her ekleme (ledger, yatırım, görev ödülü) profilde `FOR KEY SHARE` tutar, `FOR UPDATE` onunla çakışıp kilitlenme yapar (QA'da görüldü). XP tetikleyicileri bakiye kilitlerinden sonra çalışır.

## Yeni migration kontrol listesi

1. `npx supabase migration new <ad>` — buluta gönderilmiş migration **düzenlenmez**, düzeltme yeni dosyadır.
2. Yukarıdaki kalıplar (revoke/grant, RLS, search_path).
3. Her yeni tablo / politika / fonksiyon için en az bir izin + bir ret testi ([testler.md](testler.md)).
4. `npx supabase db push`, sonra `npm run db:test`; para veya bahsi değiştirdiysen `npm run db:test:concurrency`.
5. `npx supabase db advisors --linked --type security` — yeni uyarı var mı; `12_guvenlik` testi şema kurallarını zaten tarar.
6. Kararsa `KARARLAR.md`'ye, yapıysa ilgili bölge dosyasına işle.
7. `profiles`'a kolon eklersen istemci okuma izni kolon kolondur: `grant select (...) on public.profiles to authenticated` listesine ekle (ya da bilinçli kapalı bırak); `12_guvenlik` kolon listesini denetler.

## Hata kodları (SQLSTATE)

| Kod | Anlamı |
|---|---|
| `KB001` | Yetersiz bakiye |
| `KB002` | Okul maili doğrulanmamış |
| `KB003` | Bahis yatırıma kapalı (süresi geçti / kilitli / sonuçlandı) |
| `KB004` | Bu bahse zaten yatırım yapıldı |
| `KB005` | Bahis henüz kilitlenmedi, sonuçlandırılamaz |
| `KB006` | Bahis zaten sonuçlandı ya da iptal edildi |
| `KB007` | Mail adresi kişinin okulunun öğrenci alan adında değil |
| `KB008` | Okul maili başka bir hesaba bağlı |
| `KB009` | Okul maili zaten doğrulanmış |
| `KB010` | Kod isteme sınırı (60 sn bekleme / günde 5) |
| `KB011` | Doğrulama kodunun süresi doldu |
| `KB012` | Doğrulama kodunda deneme hakkı bitti |
| `KB013` | Mail servisi yapılandırılmamış |
| `KB014` | Hakemlik / sosyal bahis açma hakkı ihtar sınırı yüzünden kısıtlı |
| `KB015` | Sosyal bahsin sonucu zaten girildi |
| `KB016` | Sonuca şu an itiraz edilemez (itiraz süresi yok ya da bitti) |
| `KB017` | Çözülecek açık itiraz yok |
| `KB018` | Düello katılıma ya da oynamaya açık değil (rakibi var / süresi doldu / zaten oynandı) |
| `KB019` | Görev henüz tamamlanmadı |
| `KB020` | Görevin ödülü bu dönem zaten alındı |
| `KB021` | Ürün satışta değil (kapalı / satış tarihi dışında) |
| `KB022` | Ürün zaten kişinin envanterinde |
| `KB023` | Kişinin seviyesi ürünün en az seviyesine yetmiyor |
| `KB024` | Sonuçlanmamış bahis / düello / hakemlik varken hesap silinemez |
| `KB025` | Hesap silinmiş ya da yasaklı: istek bekçisi (`guard.check_request`) her API isteğini reddeder |
| `KB027` | Başarım henüz kazanılmadı (ilerleme hedefe ulaşmadı) |
| `KB028` | Başarımın ödülü zaten alındı |
| `KB029` | Kampüs görevi: QR kodu geçersiz ya da süresi geçti |
| `KB030` | Kampüs görevi bu dönem zaten yapıldı (onaylı ya da bekleyen gönderi var) |
| `KB031` | Kampüs görevinin kontenjanı doldu |
| `KB032` | Kampüs görevi şu an açık değil (kapalı, başlamadı, bitti ya da doğrulama yöntemi farklı) |
| `KB033` | Kampüs gönderisi zaten karara bağlandı (onay / ret yeniden yapılamaz) |
| `KB034` | Kampüs gönderisinin fotoğrafı yok, kişinin klasöründe değil ya da daha önce kullanıldı |
| `KB035` | Kişinin bugünkü kampüs görevi sınırı doldu (`campus_task_daily_limit`) |
| `KB036` | Gönderenin hesabı yasaklı ya da silinmiş: gönderi yalnızca reddedilebilir |
| `KB037` | Kampüs kelimesi: tahmin kelimeyle aynı uzunlukta değil |
| `KB038` | Kampüs kelimesi: tahmin sözlükte yok (ve günün kelimesi değil) |
| `KB039` | Kampüs kelimesi: kişinin bugünkü oyunu bitti |
| `KB040` | Kampüs kelimesi: oynanmaya başlanan kelime değiştirilemez / silinemez |
| `KB041` | Kampüs kelimesi: bugün genel kelime oynanırken okula bugün için kelime girilemez |
| `KB026` | İstek sınırı: kişinin son bir dakikadaki yazma isteği `economy_settings.api_write_limit_per_minute`'a ulaştı (bekçi) |
| `42501` | Yetki yok / giriş gerekli |
| `23514` | Geçersiz değer (kısıt) |
| `23505` | Tekrar (benzersizlik) |
| `23503` | Bağlı kayıt yok (ör. üst küme bulunamadı) |
| `P0002` | Bulunamadı (görme yetkisi olmayan kayıt dahil) |
| `55000` | Yalnızca eklenen tabloda değişiklik denemesi |
| `22003` | Üst sınır aşıldı (admin para işlemi) |

## Enum'lar

`cluster_type` (school, department, club, group) · `user_role` (student, yetkili, superadmin) ·
`membership_role` (member, owner) · `permission_key` (resmi_bahis_ac, resmi_bahis_kapat,
kullanici_bahsi_denetle, market_yonet, gorev_yonet, kullanici_yonet, analitik_gor) ·
`currency` (SP, SSP) · `ledger_reason` (signup_bonus, daily_login, quest_reward, bet_stake, bet_payout,
bet_refund, market_purchase, admin_grant, admin_adjust, achievement_reward) · `ledger_ref_type` (bet, wager, quest, market_item, achievement) ·
`bet_type` (ssp_official, sp_minigame, sp_social) · `bet_scope` (private, school, cross_school, global) ·
`bet_status` (open, locked, settling, settled, cancelled) · `settlement_mode` (auto, admin, referee) ·
`quest_period` (daily, weekly, seasonal) · `quest_action` (wager, prediction, duel, social_bet, win) ·
`market_category` (title, badge, frame, name_color) · `leaderboard_period` (week, all_time) ·
`leaderboard_metric` (hit_rate, sp_profit, ssp_profit, best_streak) · `xp_reason` (daily_login, quest, correct_pick, achievement) · `achievement_category` (prediction, streak, duel, social, loyalty, progress, secret).
