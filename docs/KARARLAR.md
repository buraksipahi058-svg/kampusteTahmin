# Kararlar

Bu dosya `MIMARI.md`'nin yanında yaşar: kesinleşen kararları ve henüz onay bekleyen önerileri tutar. Bir öneri onaylanınca "Kesinleşen" bölümüne taşınır, gerekiyorsa `MIMARI.md` de güncellenir.

## Kesinleşen kararlar

| Tarih | Konu | Karar |
|---|---|---|
| 2026-10-20 | Flutter geliştirme ortamı | Windows'a kurulur (Flutter SDK + Android Studio) |
| 2026-10-20 | Supabase geliştirme ortamı | Supabase Cloud (ücretsiz plan, Frankfurt). Şema değişiklikleri `supabase/migrations` altında migration olarak tutulur ve CLI ile buluta gönderilir; panelden elle şema değişikliği yapılmaz. (İlk karar host 192.168.1.13 idi; host erişilemez olunca değiştirildi.) |
| 2026-10-20 | Admin paneli | Next.js, Windows'ta çalışır. Secret key kullanmaz; yetki kontrolü veritabanında |
| 2026-11-22 | Repo | Çalışma yerel git'te sürer. GitHub uzak deposu (`origin` = KeremC23/BIL403-Grup01) var ama kullanıcı yeniden açıkça istemedikçe push yapılmaz. Kullanıcı söyleyene kadar yerel commit de atılmaz; değişiklikler çalışma ağacında birikir. |
| 2026-10-20 | Tablo adları (MIMARI §7'den sapmalar) | `users` yerine `profiles` (Supabase'in `auth.users` tablosuyla karışmasın). Okulun `email_domain` kolonu yerine `school_email_domains` tablosu (bir okulun birden fazla öğrenci alan adı olabilir). `student_email` ve doğrulama zamanı `profile_private` tablosunda (yalnızca kişi kendisi ve kullanıcı yönetme yetkisi olan görür); `email_verified` yerine `student_email_verified_at`. |
| 2026-10-20 | Profil oluşturma | Kayıttan sonra, giriş yapmış kullanıcı `create_profile` fonksiyonunu çağırır; profil ve okul üyeliği tek işlemde açılır. Mail onayı bitmemiş ya da anonim oturum profil açamaz. Google ile giriş gibi yöntemler de aynı yoldan geçer. |
| 2026-10-20 | Yazma yetkisi | İstemci hiçbir tabloya doğrudan satır ekleyemez/silemez. Kullanıcı yalnızca kendi ad, soyad ve bölümünü güncelleyebilir. Diğer her yazma işlemi yetki kontrolü içeren veritabanı fonksiyonlarıyla yapılır. |
| 2026-10-20 | Yetki kapsamı | İzin bayrakları okul kümesine verilir, o okulun tüm alt kümelerinde geçerlidir. `ssp_ver` / `bakiye_duzelt` bayrak değildir, yalnızca süperadmin yapar. İzin verme/alma `admin_audit_log`'a yazılır; bu tablo yalnızca eklenir. İzin alan öğrenci `yetkili` olur, izni kalmayınca `student`'a döner. |
| 2026-10-20 | SP / SSP transferi | Kullanıcılar arasında SP veya SSP transferi yok; böyle bir fonksiyon yazılmaz. (Eski öneri 1.) |
| 2026-10-20 | Para hareketinin tek kapısı | Bakiye yalnızca `private.post_ledger` ile değişir: bakiye satırını kilitler, negatife düşürmez (hata kodu `KB001` = yetersiz bakiye), ledger'a `balance_after` ile yazar. Birden fazla kullanıcının bakiyesine dokunan işlemler (ör. bahis sonuçlandırma) kilitlenmeyi önlemek için kullanıcıları `user_id` sırasıyla işler. |
| 2026-10-20 | Ledger kuralları | Yalnızca eklenir. Harcamalar (`bet_stake`, `market_purchase`) eksi, kazançlar artı; `admin_adjust` iki yönlü. Başlangıç ve günlük ödül yalnızca SP. Admin işlemlerinde kimin yaptığı ve gerekçe zorunlu. Başlangıç SP'si kişi başı bir kez (veritabanı kısıtı). |
| 2026-10-20 | Ekonomi ayarları (taslak) | `economy_settings` tek satır: başlangıç 1000 SP; günlük ödül 50 + 10 × (seri − 1), en fazla 150; seri kilometre taşları 7. gün +200, 14. gün +500, 30. gün +1500. Gün İstanbul saatine göre değişir. Rakamlar market fiyatlarıyla (Adım 9) kalibre edilecek. |
| 2026-10-20 | Süperadmin para işlemleri | `admin_grant` (yalnızca artı) ve `admin_adjust` (iki yönlü). Gerekçe zorunlu, tek işlemde en fazla 1.000.000, süperadmin kendi bakiyesini değiştiremez. |
| 2026-10-20 | Eşzamanlılık testi | `npm run db:test:concurrency` gerçek paralel isteklerle çalışır ve veritabanı şifresi ister (kökteki `.env.local` içinde `SUPABASE_DB_PASSWORD`, git'e girmez). Sebep: şifresiz CLI her çağrıda geçici giriş rolünün şifresini yeniler, paralel çağrılar birbirini bozar. |
| 2026-10-20 | Okul maili doğrulaması | Bahis açmak da bahse yatırım yapmak da doğrulanmış okul maili ister (hata kodu `KB002`). Bir okul maili yalnızca bir hesaba bağlanır. (Eski öneri 2.) |
| 2026-10-20 | Bahis çekirdeği | Bahis açma / kilitleme / sonuçlandırma / iptal iç fonksiyonlardır (`private.create_bet`, `lock_bet`, `settle_bet`, `cancel_bet`); türe özel ve yetki kontrollü RPC'ler Adım 6-8'de bunları çağırır. İstemciye açık tek bahis yazma işlemi `place_wager`. v1'de kapsam yalnızca `school` ve `private` (grup/kulüp/bölüm). |
| 2026-10-20 | Yatırım kuralları | Kişi bir bahse bir kez yatırım yapar (`KB004`). Sonucu belirleyen (sosyal bahiste hakem; resmi bahiste açan ve o okulda `resmi_bahis_kapat` izni olan, süperadmin) yatırım yapamaz. Bahis yalnızca kümesinin üyelerine görünür; bireysel yatırımlar gizli, havuz toplamları açık. Kapanış zamanı geçen ya da kilitlenen bahse yatırım yapılamaz (`KB003`). |
| 2026-10-20 | Pari-mutuel dağıtım | Kesinti yok. Kazananlar tüm havuzu yatırımları oranında paylaşır; tam sayı bölmeden kalan SP'ler kesirli payı en büyük olandan başlayarak 1'er dağıtılır (havuzun tamamı dağıtılır). Kazanan seçeneğe kimse yatırmadıysa herkese iade. Sosyal havuz ve mini oyun her zaman havuzdur. |
| 2026-11-22 | Resmi SSP bahis oranı | Sabit oran (MIMARI §13.6; kullanıcı "sonra tekrar bakarız" dedi). Admin her seçeneğe oran verir (1,01–20,00); kazanan `floor(yatırım × oran)` SSP alır, kaybeden 0. Sistem kasa gibidir: ödeme havuzdan değil yeni SSP'den gelir, kaybedilen SSP yok olur. Veritabanında `bets.odds_mode` resmi bahiste `fixed` ya da `pool` olabilir; ileride havuza dönmek migration gerektirmez. |
| 2026-10-20 | Bahis sonuçlandırma | Yalnızca kilitli ya da kapanış zamanı geçmiş bahis sonuçlandırılır (`KB005`); sonuçlanmış/iptal edilmiş bahse tekrar dokunulamaz (`KB006`). Ledger'da her yatırımın tek yatırma ve tek ödeme/iade kaydı olabilir (benzersiz indeks). İptal gerekçe ister ve herkese iade eder. |
| 2026-10-20 | İlk süperadmin | Fonksiyonla atanmaz; proje sahibi bir kez SQL ile atar (aşağıda). |
| 2026-10-20 | Hesap silme | `auth.users` satırı profil varken silinemez (ledger bütünlüğü). Hesap silme Adım 11'de soft delete + anonimleştirme olarak yapılacak. |
| 2026-10-20 | Testler | pgTAP, `npm run db:test` (= `supabase test db --linked`) ile buluttaki veritabanında çalışır; her test dosyası tek transaction'dır ve sonunda geri alınır. Docker Desktop açık olmalı. |
| 2026-10-20 | Mobil temel | Flutter'da durum yönetimi Riverpod, yönlendirme go_router. Supabase URL + publishable key `mobile/.env`'den (`--dart-define-from-file`, git'e girmez). Sunucu hataları tek eşlemeyle (`lib/core/error_messages.dart`) kullanıcı diline çevrilir, ham sunucu metni gösterilmez. Görünen ad `AppInfo.name`'de; platform dosyaları testle denetlenir. Riverpod'un otomatik yeniden denemesi kapalı (RPC'ler habersiz tekrarlanmasın). |

### İlk süperadmini atama

Süperadmin olacak kişi önce uygulamaya kaydolup profilini oluşturur, sonra proje klasöründe:

```bash
npx supabase db query --linked "update public.profiles set role = 'superadmin' where id = (select id from auth.users where email = 'MAIL_ADRESI')"
```

## Adım planı

Her adımın sonunda durulur, rapor verilir, onay beklenir.

| # | Adım | Çıktı |
|---|---|---|
| 0 | Ortam + iskelet | Repo, Supabase, Flutter ve admin projeleri ayakta |
| 1 | Şema + RLS | Kümeler, profiller, üyelikler, yetkiler; tek okul seed'i |
| 2 | Para çekirdeği | Ledger + bakiye fonksiyonları, günlük giriş / seri; eşzamanlılık testleri |
| 3 | Bahis çekirdeği | Bahis, seçenek, yatırım; pari-mutuel sonuçlandırma, iptal + iade; testler |
| 4 | Mobil temel | Kayıt / giriş, sekmeler, bakiye, profil |
| 5 | Okul maili doğrulama | Kod gönderimi ve doğrulama |
| 6 | Resmi SSP bahisler + admin | RBAC; panelden aç / kilitle / sonuçlandır |
| 7 | Sosyal havuz | Hakem, itiraz penceresi, moderatör kuyruğu |
| 8 | Mini oyunlar | Trivia + düello, kontrol sunucuda |
| 9 | Görevler + market | Envanter, kozmetik kuşanma |
| 10 | Liderlik + istatistik | Haftalık snapshot |
| 11 | Güvenlik denetimi + uçtan uca test | RLS saldırı testleri, hesap silme, KVKK |

## Onay bekleyen öneriler

1. ~~Kullanıcılar arası SP/SSP transferi yok.~~ Kesinleşti (2026-10-20). Kalan risk: düello / sosyal havuzla bilerek kaybedip SP aktarma; düşük limit ve aynı kişilerin sık eşleşmesinin izlenmesiyle sınırlanacak (Adım 7-8).
2. ~~Bahse katılmak da okul maili doğrulaması ister.~~ Kesinleşti (2026-10-20).
3. ~~Para hareketleri yalnızca sunucu fonksiyonlarıyla.~~ Adım 2'de bu şekilde uygulandı (bkz. "Para hareketinin tek kapısı").
4. **Mini oyunlarda kontrol sunucuda:** trivia'nın doğru cevabı istemciye gitmez, cevap ve süre sunucuda kontrol edilir; reflex oyunu SP'siz (yalnızca skor); zar / çark sonucu sunucuda üretilir.
5. **v1'de düello = trivia düellosu** (aynı soruları çözen iki kişi). Gerçek dünya olayına bağlı düello Tip-2 sosyal havuz sayılır.
6. **İsim ve "bahis" dili** mağaza incelemesinde ve okullar nezdinde risk taşır; "tahmin" dili düşünülebilir. Görünen ad kodda tek bir yerde tutulur. Yayın öncesi hukuki görüş alınmalı.
7. **Mağaza zorunlulukları:** uygulama içinden hesap silme (ledger silinmez, kullanıcı anonimleştirilir) ve KVKK aydınlatma metni. Veri Supabase'in Frankfurt bölgesinde (yurt dışı) tutulduğu için metin yurt dışına aktarımı da kapsamalı.
8. **v1 Android öncelikli.** iOS derlemesi Mac ya da bulut CI ister.

## İlgili adımda çözülecek ayrıntılar

- Bahis kilitleme (`locks_at`) ve itiraz penceresi kapanışı için zamanlanmış iş (pg_cron).
- Para dışı admin işlemleri (ban, yetki verme) için ayrı denetim kaydı.
- MIMARI §13'teki rakamlar (başlangıç SP, limitler, itibar eşikleri) bir ayar tablosunda tutulur, sonra kalibre edilir.
