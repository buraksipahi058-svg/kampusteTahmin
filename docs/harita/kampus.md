# Bölge: Bildirimler ve kampüs görevleri

Adım 17 (uygulama içi bildirimler), 17a (QR'lı kampüs görevleri), 17b (fotoğraflı görevler, onay kuyruğu).
Kurallar: KARARLAR "Uygulama içi bildirimler", "Kampüs görevleri". Genel kalıplar: [veritabani](veritabani.md).

## Bildirimler (Adım 17)

Kod: `20261122214819_bildirimler.sql`. Test: `19_bildirimler.test.sql` (26).

- `notifications` (kişi, tür, başlık, metin, `link` uygulama içi yol, `dedupe_key`, `read_at`). RLS: yalnızca kendi
  satırları; istemci yazamaz. Aynı olay iki kez yazılmaz (`(user_id, dedupe_key)` benzersiz).
- Üreticiler (tetikleyici): bahis durumu (`bets_notify_status`: sonuçlandı → kazandın / iade / kaybettin; iptal;
  sosyal bahiste hakem sonucu girdi), itiraz (`bet_disputes_notify`: hakeme, okulun moderatörlerine, karar itiraz edene),
  düello (`trivia_duels_notify`: davet, kabul), profil (`profiles_notify`: seviye atlama, hakem ihtarı; silinince
  bildirimleri silinir), yönetici para işlemi (`ledger_entries_notify_admin`). Silinmiş hesaba yazılmaz.
- **pg_cron** `kampusbet_bildirimler` 5 dakikada bir `private.process_notifications()`: kapanışı geçen ve sonucu
  girilmemiş sosyal bahsin hakemine hatırlatma (bir kez), 90 günden eski bildirimleri siler.
- `mark_notifications_read(ids?)` → işaretlenen sayısı (null: hepsi; başkasının bildirimi etkilenmez).
- Mobil: üst çubukta zil (`NotificationBell`, okunmamış sayısı; dakikada bir ve uygulamaya dönülünce yenilenir),
  `/bildirimler` (dokununca okundu + bağlantı: sekmeyse geçer, değilse açar; "Tümünü okundu say"). Push (Firebase) yok.

## Kampüs görevleri — QR (Adım 17a)

Kod: `20261122215319_kampus_gorevi_degerleri.sql` (enum: `kampus_gorevi_yonet`, `campus_task_reward`, ref ve XP),
`20261122215322_kampus_gorevleri.sql`. Test: `20_kampus_gorevleri.test.sql` (38), eşzamanlılık `kampus.mjs` (5; 5. kontrol günlük sınır, güvenlik kontrolü 2).

- `campus_tasks`: okul (zorunlu, sonradan değişmez), ad, açıklama, simge, doğrulama (`qr` / `photo`, sonradan
  değişmez), dönem (`once` / `daily` / `weekly`, İstanbul), ödül (SP; SSP yalnızca süperadmin), XP, kontenjan,
  `qr_rotation_seconds` (0 basılı sabit kod; 30–300 ekranda dönen kod), başlangıç / bitiş, açık. RLS: okulun
  öğrencileri açık olanları, okulunda `kampus_gorevi_yonet` olan (ve süperadmin) hepsini görür.
- `private.campus_task_secrets`: görev başına 32 bayt anahtar (API'ye kapalı). Kod = HMAC-SHA256(anahtar, görev +
  zaman dilimi) ilk 12 hex (`private.campus_qr_code`). QR içeriği:
  `com.kampusbet.kampusbet://kampus-gorev?t=<görev>&c=<kod>`.
- `campus_task_submissions`: görev, kişi, dönem başı, yöntem, durum (`pending` / `approved` / `rejected` / `expired`),
  fotoğraf yolu (17b), inceleyen, not, o anki ödül. Dönem başına bir bekleyen ya da onaylı (benzersiz kısmi indeks).
  RLS: kişinin kendisi; kişinin okulunda görevi yöneten; süperadmin.
- Yönetim: `save_campus_task(...)` (okulunda izin ya da süperadmin; SSP ödülü ve SSP'li görevi düzenleme yalnızca
  süperadmin; denetim `campus_task_save`), `reset_campus_task_qr(görev)` (yeni anahtar, eski kod geçmez; denetim),
  `campus_task_qr(görev)` → (kod, içerik, dönme süresi, geçerlilik sonu) yalnızca yöneten.
- Öğrenci: `my_campus_tasks()` (okulunun açık görevleri, bu dönemki durumu, bu dönem yapan sayısı, kalan kontenjan,
  `can_submit`), `submit_campus_task_qr(görev, kod)` → (para birimi, tutar, XP, bakiye). Ret: doğrulanmamış `KB002`,
  başka okul `P0002`, yöneten / süperadmin `42501`, kapalı / başlamamış / bitmiş `KB032`, kod geçersiz `KB029` (dönen
  QR'da şimdiki ve bir önceki dilim geçer), bu dönem yapıldı `KB030`, kontenjan doldu `KB031`. Görev satırı
  `FOR NO KEY UPDATE` ile kilitlenir (kontenjan yarışı). Ödül `campus_task_reward` / `campus_task` ref ile ledger'a,
  XP ledger tetikleyicisiyle (`xp_reason.campus_task`).
- Başarımlar: ölçüt `campus_tasks` (onaylı gönderi sayısı): Kampüs Kâşifi (1), Kampüs Gönüllüsü (10), Kampüs Efsanesi (50).
- Admin: `/kampus-gorevleri` (liste, gönderi sayısı, ekle, `[id]` düzenle, aç / kapat), `[id]/qr` (QR'ı sunucuda SVG
  üretir; dönen QR'da süresi dolunca kendiliğinden yenilenir; "QR'ı yenile"). `qrcode` paketi.
- Mobil: Oyunlar sekmesindeki "Kampüs görevleri" kartı → `/kampus-gorevleri` (`campus_screen.dart`; onay / ret
  bildirimi de buraya), `/kampus-gorevleri/:id/okut` (`mobile_scanner`; kamerasız
  "Kodu elle gir"). Kamera izni: Android eklentiden, iOS `NSCameraUsageDescription`.

## Kampüs görevleri — fotoğraf ve onay (Adım 17b)

Kod: `20261122221347_kampus_fotograf.sql`. Test: `21_kampus_fotograf.test.sql` (39).

- **Depolama:** `campus-proofs` (herkese kapalı, en fazla 2 MB, yalnızca `image/jpeg`). Dosya adı
  `<kişi>/<rastgele uuid>.jpg`. `storage.objects` politikaları: yükleme yalnızca kendi klasörüne, okul maili doğrulanmış,
  yasaklı değil, saatte en fazla 10 (`private.campus_upload_allowed`); okuma sahibi ve sahibin okulunda kampüs görevi
  yöneten / süperadmin (`private.campus_proof_readable`); güncelleme ve silme politikası yok (istemci değiştiremez,
  silemez). Storage API istekleri PostgREST bekçisinden geçmez; yasak / silinme kontrolü politikada.
- `submit_campus_task_photo(görev, yol)` → gönderi: ret `KB002`, `P0002`, `42501` (yöneten), `KB032` (açık değil ya da
  QR görevi), `KB034` (fotoğraf yok / başkasının / kullanılmış), `KB030`, `KB031`. Bekleyen gönderi; okulun yetkililerine
  günde bir `campus_review_new` bildirimi.
- `review_campus_submission(gönderi, onay, not?)`: okulunda yöneten / süperadmin; ret gerekçesi ≥ 3 (`23514`); yeniden
  karar `KB033`; onayda kontenjan yeniden denetlenir (`KB031`), ödül o an (`pay_campus_submission`). Öğrenciye
  `campus_approved` / `campus_rejected`; denetim `campus_review`. Kilit sırası: görev satırı, sonra gönderi.
- **pg_cron** `kampusbet_kampus_gonderileri` saatte bir `private.process_campus_submissions()`: 7 günde karara
  bağlanmayan gönderi `expired` (+ `campus_expired`); karardan 30 gün sonra (hesap silinince hemen) fotoğrafı Storage
  API ile siler (`private.storage_delete`, pg_net `DELETE /storage/v1/object/campus-proofs`), gönderiye bağlı olmayan
  1 günden eski yüklemeleri de siler.
- **Silme ayarı:** `private.storage_settings` (proje adresi; geliştirme projesinde dolduruldu) + Vault'ta
  `kampusbet_storage_service_key` adlı servis anahtarı (**kullanıcının işi**; anahtar yoksa silme bekler, fotoğraf kalır).
- Admin: `/kampus-gorevleri/onay` (bekleyenler, 5 dakikalık imzalı fotoğraf bağlantısı, onayla / gerekçeyle reddet).
- Mobil: `/kampus-gorevleri/:id/foto` (`image_picker` yalnızca kamera; `prepareProofPhoto`: yöne göre döndür, uzun kenar
  ≤ 1280, EXIF tamamen silinir, JPEG 80, 900 KB'ı aşarsa kalite düşer; `CampusApi.submitPhoto` yükler + gönderir).

## Güvenlik kontrolü 2 sonrası kurallar

Kod: `20261122223007_guvenlik_duzeltmeleri.sql`. Test: `22_guvenlik_duzeltmeleri.test.sql`.

- Yetkilinin açtığı / düzenlediği görevde ödül en çok `economy_settings.campus_task_staff_max_reward` (100) SP ve
  `campus_task_staff_max_xp` (50) XP (`23514`); süperadmin kolon sınırına kadar (1000 / 500). Admin formu tavanı gösterir (`limits.ts`).
- Kişi günde (İstanbul) en çok `campus_task_daily_limit` (5) bekleyen / onaylı gönderi yapar (`KB035`;
  `private.check_campus_daily_limit`, kişi başı danışma kilidi, görev satırı kilidinden sonra).
- SSP ödüllü görevin QR'ını alma / yenileme ve gönderisine karar yalnızca süperadmin (admin'de QR bağlantısı ve onay
  düğmeleri yetkiliye gösterilmez). Kişi kendi gönderisine karar veremez (`42501`); yasaklı / silinmiş hesabın
  gönderisi onaylanamaz (`KB036`), reddedilir.
- Depolama: dosya en çok 1 MB; kişi başı saatte 10, günde 30 yükleme (sayım danışma kilidinden sonra); yasaklı /
  silinmiş yetkili fotoğraf göremez.
