# Bölge: Kimlik, kümeler, yetkiler

Okullar ve alt kümeler, profiller, okul maili, üyelikler, yetkili izinleri. Adım 1'de kuruldu;
okul maili doğrulaması Adım 5'te buraya eklenecek. Genel veritabanı kalıpları: [veritabani.md](veritabani.md).

Kod: `supabase/migrations/20261020145105_kumeler_profiller_yetkiler.sql`, `..145832_kume_ust_kume_hatasi.sql`.
Testler: `supabase/tests/database/01_kumeler_profiller_yetkiler.test.sql` (52).

## Tablolar

| Tablo | Ne tutar | Kim görür | Kim yazar |
|---|---|---|---|
| `clusters` | Okul (kök) ve alt kümeler (bölüm, kulüp, grup). `school_id` her satırda kök okul (okulda kendisi). Tür ve üst küme sonradan değişmez. | Okullar herkese; alt kümeler okulun öğrencilerine; gruplar yalnızca üyelerine; süperadmin hepsini | Yalnızca migration/iç fonksiyon |
| `school_email_domains` | Okulun öğrenci mail alan adları (çok olabilir, küçük harf) | Giriş yapan herkes | migration |
| `profiles` | Ad, soyad, okul, bölüm, rol, XP, seviye. `id` = `auth.users.id` (silinemez: restrict) | Kendisi, aynı okul, süperadmin | `create_profile`; kullanıcı yalnızca ad/soyad/bölüm |
| `profile_private` | Okul maili (benzersiz: 1 mail = 1 hesap), doğrulama zamanı | Kendisi + okulunda `kullanici_yonet` izni olan + süperadmin | Adım 5'teki doğrulama akışı (henüz yok) |
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

## Roller

- **Süperadmin:** fonksiyonla atanmaz; SQL ile bir kez atanır (komut `KARARLAR.md` "İlk süperadmini atama").
- **Yetkili:** izin bayrağı olan öğrenci. Tehlikeli para işlemleri bayrak değil, yalnızca süperadmin.
- **Öğrenci:** varsayılan.

## Sıradaki işler

- **Adım 5 — okul maili doğrulama:** kullanıcı okul mailini girer → alan adı `school_email_domains`'te mi → koda dayalı doğrulama (Edge Function + mail gönderimi) → `profile_private.student_email_verified_at`. Bahis açma/yatırım `KB002` ile bunu bekliyor. Mail sağlayıcısı henüz seçilmedi.
- Grup oluşturma / gruba katılma (Adım 7 sosyal havuzla birlikte).
- Hesap silme = soft delete + anonimleştirme (Adım 11).
