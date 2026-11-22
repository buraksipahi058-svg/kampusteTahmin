# Bölge: Kimlik, kümeler, yetkiler

Okullar ve alt kümeler, profiller, okul maili, üyelikler, yetkili izinleri. Adım 1'de kuruldu;
okul maili doğrulaması Adım 5'te eklendi. Genel veritabanı kalıpları: [veritabani.md](veritabani.md).

Kod: `supabase/migrations/20261020145105_kumeler_profiller_yetkiler.sql`, `..145832_kume_ust_kume_hatasi.sql`,
`20261122080714_okul_maili_dogrulama.sql`.
Testler: `01_kumeler_profiller_yetkiler.test.sql` (52), `04_okul_maili.test.sql` (32).

## Tablolar

| Tablo | Ne tutar | Kim görür | Kim yazar |
|---|---|---|---|
| `clusters` | Okul (kök) ve alt kümeler (bölüm, kulüp, grup). `school_id` her satırda kök okul (okulda kendisi). Tür ve üst küme sonradan değişmez. | Okullar herkese; alt kümeler okulun öğrencilerine; gruplar yalnızca üyelerine; süperadmin hepsini | Yalnızca migration/iç fonksiyon |
| `school_email_domains` | Okulun öğrenci mail alan adları (çok olabilir, küçük harf) | Giriş yapan herkes | migration |
| `profiles` | Ad, soyad, okul, bölüm, rol, XP, seviye (XP / seviye `xp_events`'in önbelleği, [para](para.md)). `id` = `auth.users.id` (silinemez: restrict). `deleted_at`: hesap silindi; `banned_at`: süperadmin yasakladı ([guvenlik](guvenlik.md)) | Kendisi, aynı okul, süperadmin | `create_profile`; kullanıcı yalnızca ad/soyad/bölüm (silinmemişse); `delete_my_account` |
| `profile_private` | Okul maili (benzersiz: 1 mail = 1 hesap), doğrulama zamanı. Mail yalnızca doğrulanınca yazılır | Kendisi + okulunda `kullanici_yonet` izni olan + süperadmin | `confirm_student_email` |
| `user_clusters` | Üyelik (`member` / `owner`). Yalnızca kendi okulunun kümeleri | Aynı kümenin üyeleri | `create_profile` (okul üyeliği); grup katılımı henüz yok |
| `permissions` | Yetkili izin bayrakları; okul kümesine verilir, alt kümelerde geçerli | Kendisi + süperadmin | `grant/revoke_permission` |
| `admin_audit_log` | Para dışı yönetim işlemleri (izin ver/al). Yalnızca eklenir | Süperadmin | iç fonksiyonlar |

## Fonksiyonlar

İstemciye açık (`public`, `authenticated`):
- `create_profile(first_name, last_name, school_id, department?)` → profil + gizli profil + okul üyeliği + bakiye + seri + başlangıç SP. Anonim oturum ve ikinci profil reddedilir. Geçerli tanımı para migration'ında (`..151007`), Adım 1'deki eski.
- `grant_permission(user_id, school_id, key)` / `revoke_permission(...)` — yalnızca süperadmin; öğrenci izin alınca `yetkili` olur, izni kalmayınca `student`'a döner; denetim kaydına yazılır.

RLS yardımcıları (`private`, `authenticated` çağırabilir): `current_school_id()`, `is_superadmin()`,
`my_cluster_ids()`, `school_of_user(uid)`, `has_permission(cluster_id, key)` (süperadmin her zaman true).

İç: `private.is_verified(uid)` (Adım 3) — okul maili doğrulanmış mı.

## Okul maili doğrulama (Adım 5)

- `request_student_email_code(email) → (email, expires_at)` — mail küçük harfe/boşluksuza çevrilir; alan adı kişinin okulunun `school_email_domains`'inde olmalı (`KB007`), başka hesaba bağlı olmamalı (`KB008`), kişi zaten doğrulanmış olmamalı (`KB009`); 60 sn bekleme ve günde (İstanbul) 5 kod (`KB010`). 6 haneli kriptografik rastgele kod üretir, `private.student_email_challenges`'ta yalnızca bcrypt özetini saklar, `private.send_mail` ile gönderir. Profil satırını kilitler.
- `confirm_student_email(code) → (verified, attempts_left)` — yanlış kod hata değil (deneme sayısı kalıcı olsun diye); 10 dk süre (`KB011`), 5 deneme (`KB012`), kod istenmemişse `P0002`. Doğruysa `profile_private`'a yazar, kod kaydını siler.
- **Mail gönderimi** `private.send_mail(to, subject, text)`, ayarı `private.mail_settings` (tek satır):
  - `dev_outbox` (şu an): mail gitmez, `private.dev_outbox`'a yazılır. Okumak: `npx supabase db query --linked "select to_email, body, created_at from private.dev_outbox order by id desc limit 5"`.
  - `brevo`: `pg_net` ile Brevo API'si; anahtar Supabase Vault'ta (`api_key_secret_name`, varsayılan `brevo_api_key`), gönderen `sender_email` Brevo'da doğrulanmış olmalı. Anahtar yoksa `KB013`. Başka sağlayıcı = yeni migration.
- Kullanıcı bu tablolara hiç erişemez (private şema, yetki yok).

## Roller

- **Süperadmin:** fonksiyonla atanmaz; SQL ile bir kez atanır (komut `KARARLAR.md` "İlk süperadmini atama").
- **Yetkili:** izin bayrağı olan öğrenci. Tehlikeli para işlemleri bayrak değil, yalnızca süperadmin.
- **Öğrenci:** varsayılan.

## Sıradaki işler

- Gerçek mail sağlayıcısına geçiş (öneri Brevo; kullanıcının hesap açması ve anahtarı Vault'a koyması gerekir) ve gerçek okulun alan adı.
- Grup oluşturma / gruba katılma (Adım 7 sosyal havuzla birlikte).
- Hesap silme Adım 11'de yapıldı: [guvenlik](guvenlik.md).
