# KampüsBet — Mimari & Tasarım Dokümanı

> **Durum:** v1 taslağı (tartışmaya açık)
> **Platform:** Flutter (mobil) + ayrı web admin paneli
> **Kitle:** Üniversite öğrencileri (18+)
> **Not:** Bu doküman yaşayan bir belgedir. Kararlar değiştikçe güncellenir.

---

## 1. Vizyon & Kapsam

KampüsBet, üniversite öğrencilerinin **sanal parayla** bahis yaptığı, oyunlaştırılmış bir kampüs platformudur. Öncelik okul turnuvalarıdır; ancak kullanıcılar kendi aralarında da bahis açabilir.

**Temel kurgu:**
- İnsanlar iki tür sanal parayla bahis yapar: **SP** (normal) ve **SSP** (Süper SP, prestijli).
- Her okul önce **kendi evrenini** görür; erişim **özelden genele** doğru genişler (küme/scope modeli).
- Gerçek öğrenci doğrulaması **okul maili** ile yapılır (bahis açarken zorunlu).
- Para, **günlük giriş + görevlerle** kazanılır.
- **Kozmetik market**, haftalık **liderlik tablosu**, kişisel **profil** ve geniş **oyunlaştırma** vardır.

**İleride (v2+):** Kampüsler/okullar arası bahis turnuvaları.

---

## 2. Değişmez İlkeler (bunlara dokunmuyoruz)

1. **Gerçek para yok, nakde çevrilmez.** SP/SSP satılmaz, geri bozdurulamaz. Bu, uygulamayı "oyun" kategorisinde tutar; "kumar" regülasyonundan ve mağaza yasaklarından uzak kalır.
2. **Market pay-to-win değildir.** Satın alınan hiçbir şey bahis şansını/oranını etkilemez — hepsi kozmetik/prestij.
3. **Para defteri (ledger) tek gerçektir.** Bakiye asla tek bir sayı olarak tutulmaz; her hareket kayıt altına alınır, bakiye oradan hesaplanır.
4. **SSP prestiji korunur.** SSP, SP'ye çevrilmez (ya da sadece tek yönlü ve kısıtlı).
5. **Çoklu okul baştan.** `cluster_id` her tabloda birinci sınıf vatandaştır; MVP tek okulla başlar ama şema N okulu destekler.

---

## 3. Para Ekonomisi

### 3.1 İki para birimi

| | **SP** (Sanal Para) | **SSP** (Süper SP) |
|---|---|---|
| Nasıl kazanılır | Günlük giriş, görevler, SP bahisleri | Resmi turnuva görevleri, süperadmin eli |
| Nerede kullanılır | SP bahisleri (mini oyun + sosyal havuz), market | SSP resmi bahisler, özel market vitrini |
| Prestij | Normal | Yüksek |
| SP'ye çevrilir mi | — | Hayır (ya da tek yönlü, kısıtlı) |

### 3.2 Ledger (append-only işlem defteri)

Her SP/SSP hareketi `ledger_entries` tablosuna **yalnızca eklenerek** yazılır. Silme/güncelleme yok. Bakiye bu kayıtların toplamıdır (performans için ayrıca önbelleklenir).

Her kaydın tuttuğu bilgi: kullanıcı, para birimi (SP/SSP), miktar (+/−), **sebep** (`daily_login`, `quest_reward`, `bet_stake`, `bet_payout`, `bet_refund`, `market_purchase`, `admin_grant`, `admin_adjust`), ilişkili nesne (hangi bahis/görev/ürün), zaman damgası.

**Neden böyle:**
- Yarış koşullarında (race condition) para çoğalması/kaybolması engellenir.
- "Bu SP nereden geldi?" her zaman cevaplanabilir → denetlenebilirlik.
- Dolandırıcılık tespiti kolaylaşır.

**Teknik gereksinim:** Bakiyeyi değiştiren her işlem **tek bir atomik transaction** içinde olmalı (ACID). Bu yüzden backend ilişkisel/Postgres tabanlı (bkz. §9).

### 3.3 Başlangıç & akış dengesi

- Yeni kullanıcı **cömert** bir SP ile başlar (net rakam marketle birlikte ayarlanır).
- Günlük giriş serisi (streak) artan SP verir.
- **SSP sadece** resmi görevlerden veya süperadmin elinden gelir → kıt ve değerli kalır.
- Para musluğu (kazanç) ↔ para gideri (market/bahis) dengesi, market fiyatlarıyla kalibre edilir.

---

## 4. Bahis Sistemleri

Üç tür bahis var. Hepsinin ortak noktası: **"kim kazandı" kararının nasıl verildiği** net tanımlı.

### 4.1 SSP — Resmi Turnuva Bahisleri

- Gerçek okul turnuvalarına/olaylarına bağlı.
- **Yetkili/süperadmin açar ve kanıtla kapatır** (oracle = yönetici).
- Oran: istenirse sabit oran; istenirse pari-mutuel havuz.
- Yüksek ödüllü, prestijli, takip edilebilir.
- Yetki `resmi_bahis_aç` / `resmi_bahis_kapat` ile kontrol edilir ve **kümeye bağlıdır** (A okulu yetkilisi B okulunun bahsini kapatamaz).

### 4.2 SP Tip 1 — Kendi Kendine Sonuçlanan Mini Oyunlar

"Kim kazandı" sorusunu **uygulama otomatik** cevaplar → anlaşmazlık yok.

Mini oyun fikirleri (beceri odaklılar öne çıkar):
- **Tahmin düellosu (1v1):** İki kişi zıt tahmin yapar, havuzu kazanan alır. Kampüse özel sorularla çok tutar.
- **Kampüs trivia:** Okula/bölüme özel soru havuzları. "Kampüs" hissi güçlü, beceri odaklı.
- **Günün tahmini (binary):** Herkese açık evet/hayır sorusu, havuz paylaşılır.
- **Reflex / hız oyunu:** Küçük, bağımsız.
- **Zar / çark (saf şans):** Basit ama **vitrinde kenarda** durur (bkz. aşağıdaki uyarı).

> ⚠️ **Tasarım uyarısı:** Crash/aviator ve saf şans oyunları en çok bağımlılık yapan mekaniklerdir. Sanal parayla bile olsa öğrenci kitlesinde bunları *baskın* yapmıyoruz. **Beceri önde (trivia, düello), şans kenarda.** Hem etik hem de uzun vadede daha sağlıklı oyun döngüsü.

### 4.3 SP Tip 2 — Güvene Dayalı Sosyal Havuz

Kullanıcılar gerçek dünya olaylarına küçük grup içinde bahis açar. Tek risk: **anlaşmazlık.** Çözüm mekanizması:

1. Her bahsin bir **hakemi** var (açan seçer; varsayılan kendisi).
2. Kapanışta kısa bir **itiraz penceresi** açılır. İtiraz yoksa sonuç kesinleşir.
3. İtiraz varsa **küme moderatörüne (yetkili)** düşer: ya sonucu belirler ya **iptal + tam iade**.
4. Hakem **itibar puanı** taşır; yalan sonuç veren kişinin bahis açma hakkı kısıtlanır.
5. Tip-2'ye **düşük bahis limiti** → büyük para dönmez, risk küçük.

> **Varsayılan davranış = iptal + tam iade.** Bu tek başına hile yapmayı anlamsız kılar (hile edenin kazancı sıfırlanır). Sosyal baskı + iade + limit üçlüsü işi halleder.

### 4.4 Oran mantığı: Pari-mutuel (havuz) sistemi

- **Kullanıcı bahisleri (SP):** Oran belirlemeye gerek yok. Herkesin koyduğu SP ortak havuza girer, kazananlar havuzu paylaşır. Kendi kendini dengeler, "kasa" gerekmez — sanal para için ideal.
- **Resmi bahisler (SSP):** İstenirse sabit oran, istenirse havuz.

---

## 5. Kümeleme & Erişim Modeli (scope)

Erişim **özelden → genele** doğru genişler. Model: **hiyerarşik, kapsam-bazlı görünürlük.**

**Küme (cluster) türleri:**
- **Okul kümesi (ana):** Mail domain'i ile doğrulanır (ör. `@ogr.uni.edu.tr`).
- **Alt kümeler:** Bölüm, kulüp, özel grup.

**Bahis görünürlük kapsamı:**
- `private` (özel grup) → `school` (okul) → `cross_school` (okullar arası, v2) → `global`

**Erişim kuralı özü:** "Bu kullanıcı bu bahsin kümesine üye mi?" Bir bahsi yalnızca kapsamındaki küme üyeleri görür/katılır.

**Teknik uygulama:** Postgres **Row-Level Security (RLS)**. Her sorgu otomatik olarak kullanıcının küme üyeliğine göre filtrelenir → erişim kontrolü veritabanı seviyesinde, neredeyse bedava.

---

## 6. Roller & Yetkiler (RBAC)

İki yönetici rolü + öğrenci. Yetkiler **tek tek bayrak (flag)** olarak tutulur; süperadmin açıp kapatır.

### 6.1 Roller

| Rol | Kapsam | Açıklama |
|---|---|---|
| **Süperadmin** | Global | Her şeye yetkili. Tek ayrıcalıklı işi: başkalarına izin dağıtmak. |
| **Yetkili** | Bir kümeye (okula) bağlı | İzinleri süperadmin açar/kapatır. Sadece kendi okulunda iş görür. |
| **Öğrenci** | Kendi kümeleri | Normal kullanıcı. |

### 6.2 Örnek izin bayrakları

- `resmi_bahis_aç` / `resmi_bahis_kapat` — SSP turnuva bahisleri
- `kullanıcı_bahsi_denetle` — Tip-2 itirazlarını çöz, bahis iptal et
- `market_yönet` — kozmetik ekle/çıkar
- `görev_yönet`
- `kullanıcı_yönet` — ban, doğrulama işlemleri
- `analitik_gör`
- `ssp_ver` / `bakiye_düzelt` — ⚠️ **tehlikeli, yalnızca süperadmin.** Ledger'a sebep yazılır. Yanlışlıkla/kötü niyetle para basmayı engeller.

### 6.3 Panel ayrımı

Admin/yetkili paneli **ayrı bir web uygulaması** olur (Flutter Web ya da basit web admin), mobil uygulamanın içinde gizli ekran **değildir.**

**Neden:**
1. **Güvenlik:** Admin kodu, herkese dağıtılan mobil pakete hiç girmez.
2. **Kullanılabilirlik:** Toplu işlemler büyük ekranda rahat.
3. **İzolasyon:** İzin ayrımı temiz kalır.

---

## 7. Veri Modeli

> Basitleştirilmiş şema. `cluster_id` çoğu tabloda bulunur ve RLS'in temelidir.

### 7.1 Ana tablolar

**clusters** — kümeler (okul / bölüm / kulüp / grup)
`id`, `name`, `type` (school/department/club/group), `parent_cluster_id` (hiyerarşi), `email_domain` (okulsa), `created_at`

**users** — kullanıcılar
`id`, `first_name`, `last_name`, `school_cluster_id`, `department`, `student_email` (nullable — sonradan doğrulanır), `email_verified` (bool), `role` (student/yetkili/superadmin), `xp`, `level`, `created_at`

**user_clusters** — kullanıcı ↔ küme üyeliği (çoka-çok)
`user_id`, `cluster_id`, `role_in_cluster`

**permissions** — yetkili izin bayrakları
`user_id`, `cluster_id`, `permission_key`, `granted_by`, `granted_at`

### 7.2 Para & ledger

**ledger_entries** — append-only işlem defteri
`id`, `user_id`, `currency` (SP/SSP), `amount` (+/−), `reason`, `ref_type` (bet/quest/market/admin), `ref_id`, `balance_after` (opsiyonel snapshot), `created_at`

**balances** — önbelleklenmiş bakiye (ledger'dan türetilir)
`user_id`, `sp_balance`, `ssp_balance`, `updated_at`

### 7.3 Bahisler

**bets** — bahis başlığı
`id`, `creator_id`, `cluster_id`, `type` (ssp_official / sp_minigame / sp_social), `currency` (SP/SSP), `title`, `description`, `scope` (private/school/cross_school/global), `status` (open/locked/settling/settled/cancelled), `settlement_mode` (auto/admin/referee), `referee_id` (Tip-2), `pool_total`, `opens_at`, `locks_at`, `settled_at`

**bet_options** — bahis seçenekleri
`id`, `bet_id`, `label`, `pool_amount` (bu seçeneğe yatan toplam), `is_winner` (null→belirlenince set edilir)

**wagers** — bireysel yatırımlar
`id`, `bet_id`, `option_id`, `user_id`, `amount`, `currency`, `payout` (sonuçlanınca), `created_at`

**disputes** — Tip-2 itirazları
`id`, `bet_id`, `raised_by`, `reason`, `status` (open/resolved/cancelled), `resolved_by`, `resolution`, `created_at`

### 7.4 Oyunlaştırma & market

**quests** — görevler
`id`, `cluster_id` (null=global), `title`, `type` (daily/weekly/seasonal), `reward_currency`, `reward_amount`, `criteria` (JSON), `starts_at`, `ends_at`

**user_quests** — ilerleme
`user_id`, `quest_id`, `progress`, `completed`, `claimed`, `completed_at`

**login_streaks** — giriş serisi
`user_id`, `current_streak`, `longest_streak`, `last_login_date`

**market_items** — kozmetik ürünler
`id`, `name`, `category` (avatar/frame/badge/theme/banner/title/emote/flair), `price`, `currency` (SP/SSP), `is_seasonal`, `available_from`, `available_until`, `cluster_scope` (null=global)

**user_inventory** — sahip olunan ürünler
`user_id`, `item_id`, `equipped`, `acquired_at`

**achievements / badges** — başarımlar
`id`, `name`, `description`, `criteria` (JSON)

**user_achievements**
`user_id`, `achievement_id`, `earned_at`

### 7.5 Liderlik

**leaderboard_snapshots** — haftalık sıralama (periyodik hesaplanır)
`id`, `cluster_id`, `period` (week/all_time), `metric` (hit_rate/total_winnings/best_streak/ssp_winnings), `user_id`, `rank`, `value`, `computed_at`

---

## 8. Ekran Haritası (kullanıcı yolculuğu)

### 8.1 Öğrenci mobil uygulaması

```
Açılış
 ├─ Kayıt (isim, soyisim, okul, bölüm)   ← öğrenci maili ZORUNLU DEĞİL
 ├─ Giriş
 │
 ├─ ANA SEKME (Bahisler)
 │   ├─ Resmi bahisler (SSP) — turnuva vitrini
 │   ├─ Mini oyunlar (SP Tip-1)
 │   ├─ Sosyal havuzlar (SP Tip-2)
 │   └─ [Bahis aç] → öğrenci maili doğrulanmamışsa → DOĞRULAMA AKIŞI
 │
 ├─ OYUNLAR SEKMESİ
 │   ├─ Trivia, düello, günün tahmini, reflex, (şans oyunları kenarda)
 │
 ├─ MARKET SEKMESİ
 │   ├─ SP vitrini (kozmetik)
 │   └─ SSP özel vitrini
 │
 ├─ LİDERLİK SEKMESİ
 │   ├─ Haftalık (hit rate / en çok kazanan / en iyi seri)
 │   └─ Okul geneli (all-time)
 │
 ├─ PROFİL SEKMESİ
 │   ├─ Avatar + kozmetikler, seviye/XP, rozetler
 │   ├─ İstatistikler: oynanan oyunlar, kazançlar, isabet oranı, seri
 │   ├─ Geçmiş bahisler
 │   └─ Günlük giriş / görevler / streak
 │
 └─ (Bahis açarken) ÖĞRENCİ MAİLİ DOĞRULAMA
     └─ domain kontrolü + kod gönderimi
```

### 8.2 Web admin paneli (ayrı uygulama)

```
Giriş (admin/yetkili)
 ├─ Dashboard (analitik, aktif bahisler, bekleyen itirazlar)
 ├─ Resmi bahisler: aç / kilitle / kazanan belirle / kapat
 ├─ İtiraz kuyruğu (Tip-2): çöz / iptal+iade
 ├─ Görev yönetimi
 ├─ Market yönetimi (kozmetik ekle/çıkar, sezonluk)
 ├─ Kullanıcı yönetimi (ban, doğrulama, itibar)
 ├─ SSP ver / bakiye düzelt (⚠ yalnızca süperadmin)
 └─ Yetki yönetimi (süperadmin → yetkililere izin dağıt)
```

---

## 9. Teknoloji Yığını

| Katman | Seçim | Gerekçe |
|---|---|---|
| **Mobil** | Flutter | Karar verildi. Durum yönetimi: **Riverpod** önerilir. |
| **Backend/DB** | **Supabase (Postgres)** | İlişkisel model veriye birebir oturur; **RLS** küme-erişimini bedavaya çözer; ledger için gereken **ACID transaction** vardır. |
| **Auth** | Supabase Auth + mail doğrulama | Domain bazlı öğrenci maili doğrulaması. |
| **Realtime** | Supabase Realtime | Canlı bahis havuzu, liderlik güncellemesi. |
| **Admin panel** | Flutter Web veya basit web admin | Mobilden ayrı. |

> **Neden Firebase değil:** Firestore ile daha hızlı başlanır ama ledger ve tutarlılıkta (eventual consistency, sınırlı transaction) zorlar. Para işin merkezinde olduğu için Postgres/Supabase tercih edilir.

---

## 10. v1 Kapsamı & Yol Haritası

### v1 (MVP) — tek okul, çoklu altyapı hazır
- Kayıt + giriş (mail doğrulama bahiste)
- Küme modeli + RLS (tek okul seed'li)
- Ledger + bakiye
- SSP resmi bahisler (yönetici kapatır)
- SP Tip-1 mini oyunlar (en az trivia + düello)
- SP Tip-2 sosyal havuz (hakem + itiraz + iade)
- Pari-mutuel havuz
- Günlük giriş + temel görevler
- Kozmetik market (temel kategoriler)
- Haftalık liderlik (beceri odaklı metrikler)
- Profil + istatistik
- RBAC + ayrı web admin paneli

### v2+
- Okullar/kampüsler arası bahis turnuvaları
- Sezonluk "battle-pass" tarzı turnuva görev zincirleri
- Genişletilmiş mini oyun kütüphanesi
- Gelişmiş analitik & dolandırıcılık tespiti

---

## 11. Oyunlaştırma Özeti

- **Günlük giriş serisi (streak):** artan SP, 7/14/30 gün kilometre taşları
- **Günlük + haftalık görevler:** "3 bahis yap", "farklı kümede bahis aç" vb.
- **XP + seviye:** paradan ayrı ilerleme; seviyeyle özellik/market açılır → "çok bahis = iyi" baskısını azaltır
- **Başarım/rozet koleksiyonu**
- **Kazanma serisi + isabet oranı (hit rate):** beceri vurgusu
- **Turnuva sezonları:** turnuva yaklaştıkça açılan görev zinciri → sonunda SSP ödülü

> **Liderlik notu:** "En çok bahis yapan" tablosu öne çıkarılmaz (sağlıksız davranışı teşvik eder). Öne çıkan: **isabet oranı / en çok kazanan / en iyi seri.**

---

## 12. Market Önerileri (hepsi kozmetik)

- Avatar kostümleri + çerçeveler + rozetler
- Profil teması / banner
- Liderlik tablosunda isim rengi / efekti (herkes görür → güçlü prestij)
- Bahis "flair"i (açtığın bahsin özel görünümü)
- Unvanlar ("Kehanet Ustası", "Kampüs Efsanesi")
- Sezonluk/sınırlı ürünler (turnuva temalı → koleksiyon & FOMO)
- Emote/reaksiyonlar (bahis yorumlarında)
- **Sadece SSP ile alınabilen özel vitrin** → SSP'ye gerçek değer katar

---

## 13. Açık Sorular / Sonraki Adımlar

1. **Şans oyunları** vitrinde ne kadar yer alsın? (Öneri: kenarda, beceri oyunları önde.)
2. **Başlangıç SP miktarı** ve market fiyat skalası — ekonomiyi birlikte kalibre edelim.
3. **Tip-2 bahis limiti** kaç olsun?
4. **İtibar puanı** eşikleri (kaç yanlış sonuçta kısıtlama?)
5. **Mini oyun önceliği:** v1'de hangi 2-3 oyunla başlıyoruz?
6. Oran modeli: resmi SSP bahislerde **sabit oran mı havuz mu** varsayılan olsun?

---

*Bir sonraki adımda isteğe göre: (a) veri modelini gerçek SQL şemasına dökmek, (b) ekranların tıklanabilir akışını çizmek, (c) ledger + pari-mutuel sonuçlanma mantığının sözde kodunu yazmak.*
