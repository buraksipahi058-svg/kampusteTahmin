# Açık işler

Adımlardan kalan **denenmemiş** şeyler, **eksikler**, **çözülmemiş sorunlar** ve **kullanıcı kararı / aksiyonu
bekleyenler**. Her adımın sonunda güncellenir: yeni madde eklenir, çözülen silinir. Madde başındaki köşeli
parantez ortaya çıktığı adım.

## Denenmemiş (kod var, gerçek ortamda doğrulanmadı)

- [6-10] **Admin panelinde giriş sonrası tüm ekranlar** (resmi bahisler, yetkiler, bakiye, itirazlar, trivia soruları, günün tahmini, görevler, market, istatistik) tarayıcıda denenmedi. Gerekli: kullanıcının kendi şifresiyle girmesi ve hesabının yetkili ya da süperadmin olması. Arkalarındaki veritabanı fonksiyonları pgTAP ve SQL ile denendi.
- [7] **Mobilde itiraz etme ve moderatör kararının** uygulama içinden uçtan uca akışı (tek gerçek hesap hakem olduğu için itiraz edemedi). pgTAP ve widget testleriyle sınandı.
- [8] Mobilde **düelloyu kabul etme** (uygulamadaki "Kabul et") ve **süre bitince kendiliğinden gönderme** uçtan uca denenmedi; denemede rakip SQL ile kabul etti. Kabul, pgTAP ve widget testiyle; süre aşımı pgTAP'le sınandı.
- [8] Düello (`kampusbet_trivia_duellolari`) ve günün tahmini (`kampusbet_gunun_tahmini`) zamanlanmış işlerinin bulutta kendiliğinden çalıştığı gözlenmedi (sosyal bahis işi gözlendi; aynı düzen). pgTAP fonksiyonları doğrudan çağırdı.
- [8] Günün tahmininde **birden çok kişiyle havuz paylaşımı** uygulamada denenmedi; emülatör denemesinde tek katılımcı vardı (kazanınca kendi 30 SP'si döndü). Çok kişili dağıtım pgTAP'te sınandı.
- [9] Uygulamada **SSP vitrininden satın alma**, kuşanılan ürünü **çıkarma**, **çerçeve / unvan / rozet**in profilde görünmesi ve **sezonluk görev** denenmedi (emülatörde SP ile "Mor isim" alındı ve kuşanıldı, bir günlük görev ödülü alındı). pgTAP ve widget testleriyle sınandı.
- [10] **Dolu bir isabet sıralaması ve çok kişili liderlik** uygulamada görülmedi: bulutta tek gerçek kullanıcı var, bu hafta 2 tahmini 5'lik eşiğin altında ("Kazanç" ve "Seri" tek kişiyle görüldü). Çok kişili sıralama, eşitlik ve eşik pgTAP'te sınandı.
- [10] **Hafta dönümü** (pazartesi 00:00 İstanbul): geçen haftanın son kez hesaplanıp donması bulutta gözlenmedi; pgTAP sınadı. 10 dakikalık `kampusbet_liderlik` işi bulutta kendiliğinden çalıştı (gözlendi).
- [10] **XP'nin günlük giriş ve doğru tahminden gelmesi, seviye atlama ve seviyeli ürünü satın alma** uygulamada gözlenmedi: emülatörde yalnızca görev ödülünün XP'si (+20) gerçek veriyle görüldü (bugünkü giriş ödülü XP'den önce alınmıştı). Hepsi pgTAP'te, giriş ve bahis XP'si eşzamanlılık testlerinde de sınandı.
- [11] **Gerçek bir hesabın uygulamadan silinmesi**: emülatördeki tek gerçek hesap (kullanıcının test hesabı) silinmedi; yalnızca onay penceresi görüldü. Silme bulutta geri alınan SQL denemesi ve pgTAP ile sınandı. Silinen hesapla giriş denemesinin ve aynı e-postayla yeniden kaydın Supabase Auth'ta nasıl davrandığı gerçek istekle denenmedi.
- [12] **Gerçek onay / şifre sıfırlama mailinin linkiyle uygulamanın açılıp oturumun başlaması**: Supabase'te Redirect URLs ayarı (kullanıcının işi) yapılmadan çalışmaz; emülatörde yalnızca şemanın uygulamayı açtığı (adb) ve release derlemesinin çalıştığı denendi. Gerçek mail gönderilmedi. Şifre değiştirme ekranı yalnızca widget testinde.
- [12] iOS URL şeması, mağazaya yükleme ve Play'in AAB'yi işlemesi denenmedi.
- [13] Admin'in yeni ekranları (Kullanıcılar, Sosyal bahisler, trivia düzenleme, oran formu) tarayıcıda denenmedi (giriş gerekir); veritabanı fonksiyonları pgTAP'te. İstek bekçisinin gerçek bir silinmiş / yasaklı hesabın isteğini canlıda `KB025` ile reddettiği denenmedi (fonksiyon pgTAP'te; canlıda anonim ve normal istekler geçiyor).
- [12-QA] Admin formlarının yeni davranışı (`ActionForm`: hata alınca girilenler kalır) tarayıcıda denenmedi (giriş gerekir); tip kontrolü ve derleme geçti.
- [5] **Okul maili kodunun gerçek mail olarak gitmesi** (Brevo yolu). Yalnızca isteğin pg_net kuyruğuna girdiği test edildi; gerçek gönderim yok.
- [4] **iOS derlemesi** hiç denenmedi (Mac ya da bulut CI gerekir).

## Eksik (yapılmadı, sonraya bırakıldı)

- [8] Mobilde **belirli bir kişiye meydan okuma** yok (hep okula açık); veritabanı destekliyor (`p_invited_id`).
- [8] Düello bitince **doğru cevapları gösterme** yok (oyuncu yalnızca skorunu görür).
- [8] Günün tahmini için okul başına "günde bir soru" sınırı ya da ileri tarihli planlama yok; yetkili istediği kadar soru açabilir.
- [7] **Grup oluşturma / gruba davetle katılma** yok; özel kapsamlı (grup) bahis veritabanında var ama oluşturulamıyor.
- [7] Mobilde sosyal bahiste **başka hakem seçme** yok (hep açan); veritabanı destekliyor.
- [7] **Bildirim** yok: itiraz gelince hakeme / moderatöre, sonuç kesinleşince katılanlara.
- [2-7] Aynı kişilerin sık eşleşmesini (SP aktarma şüphesi) izleme yok (KARARLAR öneri 1'deki kalan risk).
- [10] Eski kayıtlar için **geriye dönük XP** verilmedi: XP yalnızca bu sürümden sonraki giriş, görev ve sonuçlanan bahislerden gelir (bulutta herkes 0 XP'den başladı).
- [10] Seviye yalnızca **market ürünü** açıyor; seviyeyle özellik açma (ör. sosyal bahis açmak için en az seviye) yok.
- [10] Seviye atlayınca **bildirim / kutlama** yok; günlük ödül bildirimi XP'yi yazmıyor.
- [10] Okul maili doğrulama, hakemlik ve itirazsız kesinleşen hakem kararı **XP vermiyor**.
- [10] Admin'den **XP düzeltme** yok; `xp_level_step` değişirse mevcut seviyeler yeniden hesaplanmaz (elle: `update public.profiles set level = private.level_for_xp(xp);`).
- [9-10] Kuşanılan kozmetikler kişinin profilinde ve liderlikte görünüyor; sosyal bahis kartında (açan / hakem) ve düello rakibinde görünmüyor.
- [10] Liderlikten başkasının profiline / istatistiğine bakma yok.
- [10] Sıralamadan çıkma (gizlilik) tercihi yok: okul arkadaşları adı, soyadının baş harfini ve değerleri görür (profil tablosu zaten okula açık). KVKK metninde anıldı.
- [12] **Bildirimler** yok (push için Firebase projesi gerekir; uygulama içi bildirim kutusu da yok).
- [12] Uygulama **ikonu ve açılış ekranı** Flutter varsayılanı; hata / çökme raporlama (Crashlytics, Sentry) yok.
- [12] Şifre sıfırlama linkiyle gelince doğrudan yeni şifre ekranı açılmıyor; kullanıcı Profil > Şifreyi değiştir'e gider (maildeki ve uygulamadaki metin bunu söylüyor).
- [12] Canlı Supabase projesi kurulmadı, admin paneli yayında değil (rehber: [yayin](yayin.md)).
- [12] Bağımlılıklar güncellenmedi: `shared_preferences_android` 2.5.1 (release'te R8 kuralı gerekiyor, `proguard-rules.pro`); `flutter pub upgrade` ile 2.5.5+ / jni 1.1.2+'ya geçilince o blok kaldırılabilir.
- [11] **Veri dışa aktarma** (KVKK m. 11 bilgi isteme) uygulamada yok; metinde e-postayla başvuru yazıyor.
- [11] **Kullanım koşulları** metni, yaş sınırı ve (gerekirse) açık rıza akışı yok; yalnızca aydınlatma metni var.
- [11] Admin'den **kullanıcı silme** yok (yasaklama Adım 13'te eklendi); süperadmin hesabı uygulamadan silinemez (önce rolü SQL ile alınır). Yasaklanan kişi mobilde hata mesajı görür, uygulama kendiliğinden çıkış yapmaz.
- [12-QA] Ödül al / Kuşan / Kabul et düğmelerinde çift dokunma koruması yok (ikinci istek sunucuda reddedilir, fazladan hata bildirimi çıkar). Süperadmin öğrenci uygulamasında tüm okulların bahis ve ürünlerini görür (sorgular okula göre süzülmüyor).
- [11] RPC'lerde **hız sınırı** yok (Supabase Auth'un kendi giriş / kayıt sınırları dışında); okul maili kodunda kendi sınırımız var.
- [10] Canlı güncelleme (Supabase Realtime) yok; sıralama 10 dakikada bir hesaplanır.
- [10] Başarım / rozet koleksiyonu (MIMARI §11) yok.
- [10] Geçmiş bahisler son 100 yatırım, sayfalama yok; açılan ve hakemlik yapılan sosyal bahisler orada görünmüyor (yalnızca yatırımlar).
- [10] Admin okul özeti yalnızca bu hafta; geçmiş haftalar ve grafik yok.
- [9] Market'te tema, banner, emote ve bahis "flair"i türleri yok (v1: unvan, rozet, çerçeve, isim rengi); stoklu / sınırlı sayıda ürün yok.
- [9] Admin'de ürünün kaç kez satıldığı ve görevin kaç kişi tarafından tamamlandığı görünmüyor (analitik).
- [9] Görev türleri sabit beş eylem; "farklı kümede bahis aç" gibi ölçütler yok (grup / küme oluşturma da yok).

## Çözülmemiş sorunlar / bilinen pürüzler

- [0] `npx supabase migration new` bir kez çıkmadan takıldı; stdin kapatılıp zaman aşımıyla çalıştırılınca sorun yok (`< /dev/null`, `timeout 60`). Supabase CLI 2.121 kullanılıyor, 3.x çıktı; yükseltilmedi.
- [0-6] `npm install` sırasında `unrs-resolver` için "allow-scripts" uyarısı (npm 11 kurulum betiğini onaylamadan çalıştırmıyor). Lint şu an çalışıyor; ileride ESLint çözümleyicisi sorun çıkarırsa `npm approve-scripts unrs-resolver`.
- [8] `npx supabase db push --include-seed` ikinci kez çalışınca seed dosyasının özetini güncelledi ama satırları yazmadı (trivia soruları). Seed `npx supabase db query --linked -f supabase/seed.sql` ile çalıştırıldı (dosya tekrar çalıştırılabilir). Sebep bulunmadı.
- [9] Bash aracında `<<'EOF'` heredoc'u içindeki ters bölü (`\n`, `\'`) dosyaya yazılırken tek ters bölüye ya da gerçek satır sonuna dönüşüyor (Python ile dosya düzenlerken iki kez Dart metnini bozdu). Ters bölü gereken düzenlemelerde Edit aracını kullan.
- [8] Windows PowerShell 5.1, BOM'suz `.ps1` dosyalarındaki Türkçe karakterleri bozuk okuyor (emülatör otomasyon betiğinde görüldü); betikleri UTF-8 BOM'lu kaydet ya da komut satırından ver.
- [10] XP profil satırını kilitler; moderatörün "sonucu değiştir / iptal" kararı hakem ihtarı için de profil satırını kilitler. İki moderatör aynı anda, birinin hakemi ötekinin kazananı olan iki itirazı çözerse kilitlenme olabilir: Postgres birini hata ile geri alır, işlem tekrar denenir. Çok düşük olasılık; çözülmedi.
- [10] `dart format` (Dart 3.13) mevcut mobil kodu farklı biçimliyor; toplu biçimlendirme ilgisiz dosyalara dokunuyor. Bu adımda bir kez çalıştı, ilgisiz değişiklikler geri alındı; yalnızca yeni dosyalar biçimli.
- [5] Supabase ücretsiz plan bir hafta işlem olmazsa projeyi duraklatıyor; açmak kullanıcının işi ([ortam](ortam.md)).
- [1] Supabase advisors `public.rls_auto_enable()` için uyarı veriyor (Supabase'in kendi tetikleyicisi; zararsız, dokunulmuyor).
- [1-11] Advisors her istemci RPC'si için "authenticated `SECURITY DEFINER` çağırabiliyor" uyarısı veriyor (38): Adım 11'de gözden geçirildi, tasarım gereği kabul edildi ([guvenlik](guvenlik.md)); uyarı kalır.
- [12-QA] Hesap silme ile eşzamanlı gelen bir yatırım `KB024` denetimini geçebilir (silinen hesapta açık yatırım kalır, sonuçta anonim hesaba ödenir; zararsız). Sosyal bahis başlıkları ve itiraz gerekçeleri serbest metin: kişi kendi adını yazdıysa silmede kalır.
- [12-QA] Zamanlanmış işler (sosyal bahis, düello) birden çok bahsi tek transaction'da sonuçlandırır; aynı anda istemciden sonuçlandırılan ortak kişili bir bahisle nadiren kilitlenebilir (iş tarafı yakalar, istemci 40P01 alabilir).
- [12-QA] Oturum anahtarları cihazda şifresiz (SharedPreferences) duruyor; yedeğe girmiyor ama köklü cihazda okunabilir. Gerekirse şifreli depolama (flutter_secure_storage) ile değiştirilebilir.
- [11] Supabase'in kendi kayıtlarında (Auth güvenlik günlüğü `auth.audit_log_entries`, `pg_net` istek kayıtları) silinen kişinin e-postası bir süre kalabilir; hesap silme bunlara dokunmaz.
- [6-10] Bulutta deneme verisi duruyor (liderlik satırları bunlardan hesaplanıyor): "Test Yetkili" profili (`e2e00000-...0001`), deneme resmi ve sosyal bahisleri, bir trivia düellosu, bir günün tahmini ("E2E: Bugun kampuste kar yagar mi?"); kullanıcının test hesabı örnek alan adıyla doğrulanmış, iki görev ödülü almış (ikincisi +20 XP ile, Adım 10 XP denemesi) ve "Mor isim"i satın alıp kuşanmış.

## Kullanıcı kararı / aksiyonu bekleyenler

- **Canlıya geçiş** ([yayin](yayin.md) "Canlıya geçiş sırası"): canlı Supabase projesi; Auth'ta Site URL, Redirect URLs (`com.kampusbet.kampusbet://**`), Türkçe e-posta şablonları (`supabase/templates/`), **özel SMTP** (yerleşik mail saatte çok az gönderir); Android yükleme anahtarı (`keytool`) + `android/key.properties`; Play Console hesabı; admin için barındırma (ör. Vercel) ve alan adı; uygulama ikonu; inceleme için doğrulanmış demo hesap.
- **KVKK aydınlatma metni** (`mobile/assets/legal/kvkk_aydinlatma.txt`) taslak: veri sorumlusu, adres, iletişim e-postası, yurt dışına aktarım dayanağı (KVKK m. 9), mail sağlayıcısı ve güvenlik kaydı süresi doldurulmalı; yayından önce hukuk incelemesi (sıralamada gösterim için açık rıza gerekip gerekmediği dahil).
- Gerçek okulun adı ve öğrenci mail alan adı (şimdilik "Örnek Üniversitesi" / `ogr.ornek.edu.tr`).
- Mail sağlayıcısı hesabı (öneri Brevo) ve API anahtarının Supabase Vault'a konması ([kimlik](kimlik.md)).
- Admin panelini denemek için hesabının yetkili / süperadmin yapılması (süperadmin resmi bahse yatıramaz).
- `KARARLAR.md` açık öneriler: 6 ("bahis" adı riski), 7 (mağaza zorunlulukları), 8 (Android öncelik).
- Supabase Auth'ta sızdırılmış şifre koruması (HaveIBeenPwned) kapalı; advisors uyarıyor. Açmak panelden kullanıcının işi (Authentication ayarları; ücretsiz planda olmayabilir).
- Resmi bahiste sabit oran mı havuz mu ("sonra tekrar bakarız").
- Ekonomi rakamları taslak: başlangıç SP, günlük ödül, sosyal / düello / tahmin sınırları, itiraz süresi, ihtar sınırı, **görev ödülleri (20–150 SP) ve market fiyatları (SP 250–600, SSP 80–150)**, **liderlik isabet eşiği (5 tahmin / hafta, 20 tüm zamanlar)**, **XP (giriş 10, doğru tahmin 15, günde en fazla 60; görev günlük 20 / haftalık 50; seviye adımı 100; Altın çerçeve 3. seviye, Kehanet Ustası 5. seviye)**. Adım 9-10 kuralları (KARARLAR "Görevler", "Market", "Liderlik ve istatistik", "XP ve seviye") varsayılan olarak uygulandı.
- **Yapılacak (kullanıcı, 2026-11-22): XP rakamları ve seviye kuralları birlikte yeniden ele alınacak.** Şu an varsayılan
  uygulanıyor (KARARLAR "XP ve seviye"). Konuşulacaklar: giriş / görev / doğru tahmin XP'si ve günlük sınır, seviye
  eğrisi (adım 100), hangi ürünün hangi seviyede açılacağı, seviyenin özellik de açıp açmayacağı (ör. sosyal bahis
  açmak için 2. seviye: yeni hesaplarla SP aktarmayı da zorlaştırır), eski kayıtlara geriye dönük XP verilip
  verilmeyeceği. Rakam değişikliği yalnızca `economy_settings` / ürün / görev güncellemesidir; seviye adımı değişirse
  mevcut seviyeler yeniden hesaplanmalı ([para](para.md)).
