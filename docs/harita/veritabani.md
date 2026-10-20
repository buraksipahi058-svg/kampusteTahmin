# Bölge: Veritabanı (genel)

Herhangi bir migration, RLS politikası ya da SQL fonksiyonu yazmadan önce bu sayfa okunur.
Konu bölgeleri: [kimlik.md](kimlik.md), [para.md](para.md), [bahis.md](bahis.md). Testler: [testler.md](testler.md).

## Migration'lar (sırayla)

| Dosya | Adım | İçerik |
|---|---|---|
| `20261020145105_kumeler_profiller_yetkiler.sql` | 1 | `private` şeması, kümeler, okul alan adları, profiller, gizli profil, üyelikler, yetkiler, denetim kaydı, RLS yardımcıları, `create_profile`, `grant/revoke_permission` |
| `20261020145832_kume_ust_kume_hatasi.sql` | 1 | `private.clusters_set_school` düzeltmesi (anlaşılır hata) |
| `20261020151007_para_cekirdegi.sql` | 2 | Ekonomi ayarları, ledger, bakiye, seri, `post_ledger`, `create_profile`'ın yeni hali (bakiye + başlangıç SP), `claim_daily_login`, `admin_grant/adjust` |
| `20261020160619_bahis_cekirdegi.sql` | 3 | Bahis, seçenek, yatırım, ledger'a bahis kısıtları, `create/lock/settle/cancel_bet`, `place_wager` |

## Koda inmek gerekirse

Migration dosyalarını baştan okuma; aradığın tanımın satırını bul ve yalnızca orayı oku:

```bash
grep -n "function private.post_ledger" supabase/migrations/*.sql     # fonksiyon
grep -n "create table public.bets" supabase/migrations/*.sql         # tablo
grep -n "create policy" supabase/migrations/*.sql                    # tüm RLS politikaları
```

Aynı fonksiyon birden fazla migration'da tanımlıysa **en yeni dosyadaki** geçerlidir. Şu an iki tane var:

| Fonksiyon | Geçerli tanım | Eski tanım (okuma) |
|---|---|---|
| `public.create_profile` | `20261020151007_para_cekirdegi.sql` | `20261020145105_...` |
| `private.clusters_set_school` | `20261020145832_kume_ust_kume_hatasi.sql` | `20261020145105_...` |

Buluttaki gerçek durumu görmek daha ucuzsa: `npx supabase db query --linked "select pg_get_functiondef('public.place_wager'::regproc)"`.

`supabase/seed.sql`: tek okul — "Örnek Üniversitesi", id `10000000-0000-4000-8000-000000000001`, alan adı `ogr.ornek.edu.tr` (gerçek okul belli olunca değişecek).

## Kalıplar (yeni kod da böyle yazılır)

- **Şemalar:** `public` API'ye açık (tablolar, enum'lar, istemcinin çağırdığı RPC'ler). `private` API'ye kapalı (RLS yardımcıları, iç fonksiyonlar, tetikleyiciler).
- **Tablo yetkileri:** her yeni tabloda `revoke all ... from anon, authenticated;` sonra yalnızca `grant select ... to authenticated;`. İstemci hiçbir tabloya ekleme/silme yapamaz. Tek istisna: `profiles` için `grant update (first_name, last_name, department)`.
- **RLS:** her tabloda açık. Politikalarda `(select auth.uid())`, `(select private.is_superadmin())` gibi alt sorgu biçimi (her satırda tekrar çalışmasın). Kümeye göre görünürlük: `cluster_id in (select private.my_cluster_ids())`.
- **Fonksiyonlar:** hepsi `set search_path = ''` ve tam nitelikli adlar (`public.x`, `private.y`). İstemci RPC'leri `security definer`; başta oturum (`auth.uid()`), sonra yetki, sonra girdi kontrolü. Her fonksiyonda `revoke execute ... from public, anon;` + gerekiyorsa `grant execute ... to authenticated;`. İç fonksiyonlarda yalnızca `revoke ... from public`.
- **Yalnızca eklenen tablolar:** `private.forbid_change()` tetikleyicisi (update/delete/truncate → `55000`). Şu an: `ledger_entries`, `admin_audit_log`.
- **Metin kolonları:** `char_length` aralığı + `= btrim(...)` + kontrol karakteri yasağı (`!~ '[[:cntrl:]]'`).
- **Görünmeyen kayıt:** yetkisi olmayana "bulunamadı" (`P0002`) dönülür, "yetkin yok" değil (varlığı sızdırmamak için).
- **Kilit sırası:** bahis satırı → bakiyeler (`user_id` sırasıyla).

## Yeni migration kontrol listesi

1. `npx supabase migration new <ad>` — buluta gönderilmiş migration **düzenlenmez**, düzeltme yeni dosyadır.
2. Yukarıdaki kalıplar (revoke/grant, RLS, search_path).
3. Her yeni tablo / politika / fonksiyon için en az bir izin + bir ret testi ([testler.md](testler.md)).
4. `npx supabase db push`, sonra `npm run db:test`; para veya bahsi değiştirdiysen `npm run db:test:concurrency`.
5. `npx supabase db advisors --linked --type security` — yeni uyarı var mı.
6. Kararsa `KARARLAR.md`'ye, yapıysa ilgili bölge dosyasına işle.

## Hata kodları (SQLSTATE)

| Kod | Anlamı |
|---|---|
| `KB001` | Yetersiz bakiye |
| `KB002` | Okul maili doğrulanmamış |
| `KB003` | Bahis yatırıma kapalı (süresi geçti / kilitli / sonuçlandı) |
| `KB004` | Bu bahse zaten yatırım yapıldı |
| `KB005` | Bahis henüz kilitlenmedi, sonuçlandırılamaz |
| `KB006` | Bahis zaten sonuçlandı ya da iptal edildi |
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
bet_refund, market_purchase, admin_grant, admin_adjust) · `ledger_ref_type` (bet, wager, quest, market_item) ·
`bet_type` (ssp_official, sp_minigame, sp_social) · `bet_scope` (private, school, cross_school, global) ·
`bet_status` (open, locked, settling, settled, cancelled) · `settlement_mode` (auto, admin, referee).
