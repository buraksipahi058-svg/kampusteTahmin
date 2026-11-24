# Açık işler

Adımlardan kalan **denenmemiş** şeyler, **eksikler**, **çözülmemiş sorunlar** ve **kullanıcı kararı / aksiyonu
bekleyenler**. Her adımın sonunda güncellenir: yeni madde eklenir, çözülen silinir. Madde başındaki köşeli
parantez ortaya çıktığı adım.

## Denenmemiş (kod var, gerçek ortamda doğrulanmadı)

- [6-10] **Admin panelinde işlemler** (form gönderme: bahis açma / kilitleme / sonuçlandırma, yetki verme, bakiye, itiraz kararı, trivia, günün tahmini, görev, market) tarayıcıda denenmedi. [18d] 15 panel sayfası ile trivia / görev / market / başarım / kampüs görevi ayrıntı ve QR sayfaları süperadmin girişiyle tarayıcıda açıldı (hata yok, veri geldi); form gönderilmedi. Arkalarındaki veritabanı fonksiyonları pgTAP ve SQL ile denendi.
- [7] **Mobilde itiraz etme ve moderatör kararının** uygulama içinden uçtan uca akışı (tek gerçek hesap hakem olduğu için itiraz edemedi). pgTAP ve widget testleriyle sınandı.
- [8] Mobilde **düelloyu kabul etme** (uygulamadaki "Kabul et") ve **süre bitince kendiliğinden gönderme** uçtan uca denenmedi; denemede rakip SQL ile kabul etti. Kabul, pgTAP ve widget testiyle; süre aşımı pgTAP'le sınandı.
- [8] Düello ve günün tahmini zamanlanmış işlerinin bulutta gerçek bir süre aşımını (kabul edilmeyen düelloyu iade, sonuçsuz tahmini iptal) işlediği gözlenmedi. İşlerin kendisi çalışıyor: 2026-11-22'de beş işin hepsi düzenli ve hatasız (`cron.job_run_details`). pgTAP fonksiyonları doğrudan çağırdı.
- [8] Günün tahmininde **birden çok kişiyle havuz paylaşımı** uygulamada denenmedi; emülatör denemesinde tek katılımcı vardı (kazanınca kendi 30 SP'si döndü). Çok kişili dağıtım pgTAP'te sınandı.
- [9] Uygulamada **SSP vitrininden satın alma**, kuşanılan ürünü **çıkarma**, **çerçeve / unvan / rozet**in profilde görünmesi ve **sezonluk görev** denenmedi (emülatörde SP ile "Mor isim" alındı ve kuşanıldı, bir günlük görev ödülü alındı). pgTAP ve widget testleriyle sınandı.
- [10] **Dolu bir isabet sıralaması ve çok kişili liderlik** uygulamada görülmedi: bulutta tek gerçek kullanıcı var, bu hafta 2 tahmini 5'lik eşiğin altında ("Kazanç" ve "Seri" tek kişiyle görüldü). Çok kişili sıralama, eşitlik ve eşik pgTAP'te sınandı.
- [10] **Hafta dönümü** (pazartesi 00:00 İstanbul): geçen haftanın son kez hesaplanıp donması bulutta gözlenmedi; pgTAP sınadı. 10 dakikalık `kampusbet_liderlik` işi bulutta kendiliğinden çalıştı (gözlendi).
- [10] **XP'nin günlük giriş ve doğru tahminden gelmesi, seviye atlama ve seviyeli ürünü satın alma** uygulamada gözlenmedi: emülatörde yalnızca görev ödülünün XP'si (+20) gerçek veriyle görüldü (bugünkü giriş ödülü XP'den önce alınmıştı). Hepsi pgTAP'te, giriş ve bahis XP'si eşzamanlılık testlerinde de sınandı.
- [11] **Gerçek bir hesabın uygulamadan silinmesi**: emülatördeki tek gerçek hesap (kullanıcının test hesabı) silinmedi; yalnızca onay penceresi görüldü. Silme bulutta geri alınan SQL denemesi ve pgTAP ile sınandı. Silinen hesapla giriş denemesinin ve aynı e-postayla yeniden kaydın Supabase Auth'ta nasıl davrandığı gerçek istekle denenmedi.
- [12] **Gerçek onay / şifre sıfırlama mailinin linkiyle uygulamanın açılıp oturumun başlaması**: Supabase'te Redirect URLs ayarı (kullanıcının işi) yapılmadan çalışmaz; emülatörde yalnızca şemanın uygulamayı açtığı (adb) ve release derlemesinin çalıştığı denendi. Gerçek mail gönderilmedi. Şifre değiştirme ekranı yalnızca widget testinde.
- [12] iOS URL şeması, mağazaya yükleme ve Play'in AAB'yi işlemesi denenmedi.
- [13] Admin'in yeni ekranları (Kullanıcılar, Sosyal bahisler, trivia düzenleme) tarayıcıda açıldı [18d], işlemleri (yasakla, gerekçeyle iptal, düzenleyip kaydet, oran değiştir) denenmedi; veritabanı fonksiyonları pgTAP'te. İstek bekçisinin gerçek bir silinmiş / yasaklı hesabın isteğini canlıda `KB025` ile reddettiği denenmedi (fonksiyon pgTAP'te; canlıda anonim ve normal istekler geçiyor).
- [14] **Kayıttaki koşullar onay kutusu** gerçek bir kayıtla denenmedi (emülatördeki test hesabının oturumunu kapatmamak için); `terms_version`'ın Auth metadatasına yazıldığı gerçek istekle görülmedi. Kutu ve koşullar ekranı widget testinde, koşullar ekranı release APK'da açıldı.
- [14] **Paylaşılan veri dosyasının içeriği** cihazda açılıp okunmadı: release APK'da paylaş menüsü `kampusbet-verilerim-YYYYAAGG.json` ile açıldı (sunucu çağrısı başarılı); JSON'un biçimi widget testinde, içeriği pgTAP'te. Gmail / Drive'a gerçekten gönderilmedi.
- [14] **İstek sınırının canlıda `KB026` döndürmesi** denenmedi (dakikada 60 yazma isteği gerekir); pgTAP'te sınandı. Canlıda bekçinin yazma isteklerini saydığı (sayaçta satır) ve okumaları saymadığı görüldü.
- [15] Canlıda **davetli düello ve başka hakemli sosyal bahis açılmadı** (test hesabının SP'sini bağlamamak ve bulutta yeni deneme kaydı bırakmamak için): kişi seçme penceresi gerçek aramayla, seçim sonrası form görüldü; sunucu kuralları Adım 7-8 pgTAP'inde, istemci widget testinde.
- [15] **Şifre sıfırlama linkiyle şifre ekranının açılması** gerçek mailin linkiyle denenmedi (Redirect URLs ayarı ve mail gerekir); yalnızca kod yolu yazıldı (`passwordRecovery` olayı → `HomeShell`).
- [15] **Yasaklı / silinmiş hesabın otomatik çıkışı** canlıda denenmedi (gerçek yasaklı hesap yok); `KB025` tanıma birim testinde. **Seviye kutlaması** canlıda görülmedi (widget testinde). **Süperadmin okul süzgeci** süperadmin hesabıyla denenmedi.
- [16] Canlıda yalnızca "Kampüslü" başarımının ödülü alındı ve 2. günün günlük ödülü takvimden alındı. Gizli başarım ("Ters Köşe"), çok kişili "okulda kazanan" oranı ve 7 / 14 / 30. gün bonuslarının takvimde alınması canlıda görülmedi (pgTAP ve widget testinde). Test hesabında 5 başarımın ödülü hazır bekliyor.
- [16] Admin'in **Başarımlar** ekranında liste ve düzenleme sayfası süperadmin girişiyle açıldı [18d]; ekle, kaydet, aç / kapat denenmedi. `save_achievement` pgTAP'te.
- [17] Bildirimlerin gerçek olaylardan (bahis sonucu, itiraz, düello daveti) canlıda üretildiği görülmedi; canlıda elle eklenen deneme bildirimiyle zil, liste, okundu ve bağlantı denendi. Üreticiler pgTAP'te.
- [17a] Admin'in **Kampüs görevleri** liste, düzenleme ve QR sayfası süperadmin girişiyle açıldı [18d]; ekleme / kaydetme, dönen QR'ın kendiliğinden yenilenmesi ve yazdırma denenmedi. Kamerayla **gerçek QR okutma** denenmedi (emülatör kamerası); kamera izni, kamera görüntüsü ve elle kodla gönderi release APK'da canlı denendi. Kamera izni reddedilince ne olduğu denenmedi.
- [17b] Admin'in **fotoğraf onay kuyruğu** boş haliyle açıldı [18d]; imzalı bağlantıyla fotoğrafın görünmesi ve onayla / reddet tarayıcıda denenmedi; canlıda fotoğraf release APK'dan gerçek depolamaya yüklendi (48 KB, `image/jpeg`), onay SQL ile geçici izinli deneme profiliyle yapıldı, ödül ve bildirim uygulamada görüldü. **30 gün sonra silme** Vault anahtarı olmadığı için canlıda çalışmadı; istek kuyruğa girmesi pgTAP'te.
- [G2] **Okul maili doğrulanmamış hesapla** canlıda denenmedi (ikinci hesap yok): okul verisinin gelmemesi pgTAP'te, doğrulama kartları widget testinde. Sunucu değişikliğinden sonra doğrulanmış test hesabıyla Bahisler, Liderlik ve Profil canlıda açıldı (izin hatası yok). Emülatördeki APK eski derleme: yeni kartlar, iptal düelloda "Cevapları gör" gizlenmesi, fotoğraf kalite döngüsü içinde değil.
- [18c-logo] Yeni logodan üretilen uygulama ikonu Android emülatörde (uygulama listesi, daire maske) ve logo yükleniyor ekranında görüldü; giriş ekranı (oturum kapatılmadı) gözle görülmedi; admin giriş sayfası (2026-11-24), yan menü ve sekme ikonu görüldü. iOS ikonu üretildi ama iOS'ta denenmedi. Android 13 tema ikonu (tek renk) tanımlı değil. Mağaza için 512 px ikon `assets/brand/app_icon.png`'den (1024) üretilebilir.
- [18a-18b] Yeni tasarım emülatörde Bahisler, günün tahmini, Oyunlar, Profil, Liderlik ekranlarında açık / karanlık ve %200 yazıyla görüldü; market, düello oyunu (seçim vurgusu, geçiş), kutlama pencereleri, yatırım alt sayfası (çipler) ve titreşimler gözle / elle denenmedi (titreşim emülatörde hissedilmez). Telefona kuruldu, telefonda bakılmadı. `Pressable` henüz kullanılmıyor (Material düğmelerde dalga seçildi).
- [Oyunlar menüsü] Yeni Oyunlar menüsü (üç kart, bekleyen iş rozetleri, alt ekranlar, düello bildiriminin düello ekranına açılması) widget testleriyle denetlendi; telefonda ve emülatörde gözle bakılmadı (emülatör bağlantısı koptu), canlı düello bildirimiyle denenmedi.
- [G2] Admin'de **Kullanıcılar** (yasak bilgisi `banned_users`'tan), kampüs görevi formundaki **ödül tavanı**, SSP gönderisinde "yalnızca süperadmin" notu ve SSP görevinde gizlenen QR bağlantısı tarayıcıda giriş yapılarak denenmedi (tsc ve lint temiz, sunucu kuralları pgTAP'te).
- [12-QA] Admin formlarının davranışı (`ActionForm`: hata alınca girilenler kalır; [18d] başarıda köşe bildirimi) tarayıcıda gönderimle denenmedi; tip kontrolü, lint ve derleme geçti.
- [5] **Okul maili kodunun gerçek mail olarak gitmesi** (Brevo yolu). Yalnızca isteğin pg_net kuyruğuna girdiği test edildi; gerçek gönderim yok.
- [4] **iOS derlemesi** hiç denenmedi (Mac ya da bulut CI gerekir).
- [18-mor] Mor, fütüristik mobil tema emülatörde release APK ile ana sekmelerde ve alt ekranlarda (kampüs görevleri, görevler, başarımlar, günlük ödül, günün tahmini, düello) normal ve %200 yazıyla görüldü [18e]; 18e dahil release APK telefona kuruldu (2026-11-23), telefonda gözle bakılmadı (kullanıcı bakacak). Açık tema tanımlı ama kullanılmıyor (uygulama hep koyu açılır), gözle denetlenmedi.
- [18d] Admin paneli dar ekranda (375 px) Resmi bahisler, Market, Yetkiler ve Bakiye sayfalarında gözle denetlendi [18e]; öteki sayfalar yalnızca masaüstünde. Panel masaüstü öncelikli.
- [18e] Yeni ortak hata görünümü (`ErrorView` + "Tekrar dene") düello cevapları, kişi profili ve yasal metin ekranlarında gözle görülmedi (hata durumu üretilmedi); analiz ve 72 test temiz. Düello cevaplarının yeşil doğru / kırmızı yanlış hali emülatörde görüldü.
- [Öğretici] Gerçek yeni bir kayıtla (kayıt → okul seçimi / profil → öğretici) denenmedi: emülatörde mevcut test hesabıyla açıldı, "Başlayalım" ile kapatınca hesaba `tutorial_version = 1` yazıldı, yeniden açılışta çıkmadı; %200 yazıyla Profil'den açıldı. Çevrimdışıyken kapatma (kaydedilemezse sonraki açılışta yeniden çıkması) ve günlük ödülün öğreticiden sonra açılması yalnızca widget testinde. Telefona kuruldu (2026-11-23), telefonda gözle bakılmadı.
- [19] Kampüs kelimesi cihazda (emülatör / telefon) oynanmadı: bulutta bugün için kelime yok (test kelimesi girilmedi); oyun ekranı widget testlerinde (5 ve 8 harf, %200 yazı) denendi. Admin `/kelimeler` sayfası oturum açık hâlde görülmedi (tarayıcıdaki admin oturumu kapanmıştı; derleme, tip ve lint temiz). Admin giriş sayfası yeni logoyla görüldü.
- [19] Aynı kişinin aynı anda gönderdiği iki tahmin için eşzamanlılık testi yazılmadı (deneme satırı kilidiyle sıraya girer; pgTAP tek bağlantıda sınar).

## Eksik (yapılmadı, sonraya bırakıldı)

- [8] Günün tahmini için okul başına "günde bir soru" sınırı ya da ileri tarihli planlama yok; yetkili istediği kadar soru açabilir.
- [7] **Grup oluşturma / gruba davetle katılma** yok; özel kapsamlı (grup) bahis veritabanında var ama oluşturulamıyor.
- [7] **Bildirim** yok: itiraz gelince hakeme / moderatöre, sonuç kesinleşince katılanlara.
- [2-7] Aynı kişilerin sık eşleşmesini (SP aktarma şüphesi) izleme yok (KARARLAR öneri 1'deki kalan risk).
- [10] Eski kayıtlar için **geriye dönük XP** verilmedi: XP yalnızca bu sürümden sonraki giriş, görev ve sonuçlanan bahislerden gelir (bulutta herkes 0 XP'den başladı).
- [10] Seviye yalnızca **market ürünü** açıyor; seviyeyle özellik açma (ör. sosyal bahis açmak için en az seviye) yok.
- [10] Okul maili doğrulama, hakemlik ve itirazsız kesinleşen hakem kararı **XP vermiyor**.
- [10] Admin'den **XP düzeltme** yok; `xp_level_step` değişirse mevcut seviyeler yeniden hesaplanmaz (elle: `update public.profiles set level = private.level_for_xp(xp);`).
- [12] **Bildirimler** yok (push için Firebase projesi gerekir; uygulama içi bildirim kutusu da yok).
- [12] Uygulama **açılış ekranı** (splash) Flutter varsayılanı (ikon 18c'de yapıldı); hata / çökme raporlama (Crashlytics, Sentry) yok.
- [12] Canlı Supabase projesi kurulmadı, admin paneli yayında değil (rehber: [yayin](yayin.md)).
- [12] Bağımlılıklar güncellenmedi: `shared_preferences_android` 2.5.1 (release'te R8 kuralı gerekiyor, `proguard-rules.pro`); `flutter pub upgrade` ile 2.5.5+ / jni 1.1.2+'ya geçilince o blok kaldırılabilir.
- [14] Kullanım koşulları **değişince yeniden onay** alınmıyor; mevcut hesaplar (bulutta yalnızca test hesabı) koşulları hiç onaylamadı. Onay yalnızca Auth kullanıcı metadatasında (`terms_version`; kişi kendi metadatasını değiştirebilir), sunucuda ayrı onay kaydı yok. (Gerekirse) açık rıza akışı yok.
- [14] Sıralamada gizli olmak yalnızca liderliği kapsar: profil (ad, soyad, okul, bölüm, seviye) okul arkadaşlarına açık kalır; sosyal bahiste açan / hakem adı görünür.
- [11] Admin'den **kullanıcı silme** yok (yasaklama Adım 13'te eklendi); süperadmin hesabı uygulamadan silinemez (önce rolü SQL ile alınır).
- [10] Canlı güncelleme (Supabase Realtime) yok; sıralama 10 dakikada bir hesaplanır.
- [16-17] **Telefon bildirimi (push) yok**: bildirimler ve başarım haberi yalnızca uygulama açıkken görünür (Firebase projesi gerekir). Uygulama okunmamış sayısını dakikada bir okur (Realtime yok).
- [10] Admin okul özeti yalnızca bu hafta; geçmiş haftalar ve grafik yok.
- [9] Market'te tema, banner, emote ve bahis "flair"i türleri yok (v1: unvan, rozet, çerçeve, isim rengi); stoklu / sınırlı sayıda ürün yok.
- [9] Admin'de ürünün kaç kez satıldığı ve görevin kaç kişi tarafından tamamlandığı görünmüyor (analitik).
- [9] Görev türleri sabit beş eylem; "farklı kümede bahis aç" gibi ölçütler yok (grup / küme oluşturma da yok).
- [19] Kampüs kelimesinde istatistik / seri, sıralama, başarım ve bildirim yok; geçmiş günlerin kelimeleri oynanamaz. Admin'de kelime düzenleme yok (sil + yeniden gir). Sözlük yalnızca kök kelimeler: çoğul / çekimli biçimler tahmin edilemez.

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
- [1-11] Advisors her istemci RPC'si için "authenticated `SECURITY DEFINER` çağırabiliyor" uyarısı veriyor (Adım 19 sonu 63; yeni tür yok): Adım 11'de gözden geçirildi, tasarım gereği kabul edildi ([guvenlik](guvenlik.md)); uyarı kalır.
- [12-QA] Hesap silme ile eşzamanlı gelen bir yatırım `KB024` denetimini geçebilir (silinen hesapta açık yatırım kalır, sonuçta anonim hesaba ödenir; zararsız). Sosyal bahis başlıkları ve itiraz gerekçeleri serbest metin: kişi kendi adını yazdıysa silmede kalır.
- [12-QA] Zamanlanmış işler (sosyal bahis, düello) birden çok bahsi tek transaction'da sonuçlandırır; aynı anda istemciden sonuçlandırılan ortak kişili bir bahisle nadiren kilitlenebilir (iş tarafı yakalar, istemci 40P01 alabilir).
- [12-QA] Oturum anahtarları cihazda şifresiz (SharedPreferences) duruyor; yedeğe girmiyor ama köklü cihazda okunabilir. Gerekirse şifreli depolama (flutter_secure_storage) ile değiştirilebilir.
- [14] İstek sınırı yalnızca **başarılı yazma** isteklerini sayar: başarısız istek transaction'la geri alındığı için sayaca girmez (hatalı isteklerle boğma sınırlanmaz); okuma istekleri ve IP başına sınır yok. Tam koruma için API'nin önüne ağ geçidi (ör. Cloudflare) gerekir.
- [16] Başarım ilerlemesi her istekte kişinin bütün kayıtlarından hesaplanıyor (`achievement_metrics`); kayıt sayısı çok büyürse Profil / Başarımlar açılışı yavaşlayabilir (gerekirse önbellek ya da sayaç). Mevcut kullanıcılar geçmiş kayıtlarından kazandıkları başarımları ilk açılışta birden görür (test hesabında 6).
- [17a] QR okuyucu eklentisi (`mobile_scanner`, ML Kit modeli içinde) APK'yı 56 MB'tan 71,6 MB'a büyüttü. Küçültmek için Google Play hizmetlerindeki model kullanılabilir (`dev.steenbakker.mobile_scanner.useUnbundled=true`, ilk açılışta model indirilir); denenmedi.
- [17b] Fotoğraf silme Vault'ta servis anahtarı olmadan çalışmaz: anahtar konana dek fotoğraflar depolamada kalır (KVKK 30 gün sözü için şart; [yayin](yayin.md)). Silme isteğinin yanıtı denetlenmez; başarısız olursa sahipsiz dosya taraması ertesi gün yeniden dener. Yapay zekâyla üretilmiş ya da başka cihazda gösterilen bir fotoğrafın çekilmesi engellenemez; karar yetkilide.
- [G2] Anlaşan iki doğrulanmış hesap düello cevaplarını yine görebilir (biri kabul edip kaybeder); soru havuzu küçükse ezberlenir. Daha çok soru ve gösterilen soruyu emekliye ayırma sonraya.
- [G2] Kampüs görevi yetkilisi tavan içinde (görev başı 100 SP / 50 XP, kişi başı günde 5 görev) arkadaşlarına ödül verebilir; her görev denetim kaydında (`campus_task_save`), her ödül ledger'da görünür.
- [G2] Fotoğrafın türü yalnızca yüklemedeki başlıkla (`image/jpeg`) denetlenir, dosyanın içeriği denetlenmez (yetkili imzalı bağlantıyla `<img>` içinde görür). Storage API yükleme iznini ve kaydı ayrı transaction'larda denetliyorsa eşzamanlı yüklemeler saatlik 10'u aşabilir; günlük 30 ve 1 MB yine bağlar (denenmedi).
- [G2] Hakem ihtar sayısı (`profiles.referee_strikes`) okul arkadaşlarına açık (hakem seçerken güven bilgisi; bilinçli bırakıldı). Yasak bilgisi kapatıldı.
- [17a] Basılı QR'ın fotoğrafı paylaşılırsa başkası mekâna gitmeden yapabilir (bilinen; ödülü küçük tut, "QR'ı yenile" ya da ekran QR'ı kullan).
- [15] Kişi aramada Türkçe büyük / küçük harf (İ / i, I / ı) eşleşmesi veritabanının yerel ayarına bağlı; denenmedi ("VEL" → "Veli" testte geçti).
- [14] Sıralamadan çıkan kişinin donmuş geçmiş haftalardaki satırları da silinir, açınca o haftalara geri dönmez (o haftanın sıra numaralarında boşluk kalır).
- [11] Supabase'in kendi kayıtlarında (Auth güvenlik günlüğü `auth.audit_log_entries`, `pg_net` istek kayıtları) silinen kişinin e-postası bir süre kalabilir; hesap silme bunlara dokunmaz.
- [6-10] Bulutta deneme verisi duruyor (liderlik satırları bunlardan hesaplanıyor): "Test Yetkili" profili (`e2e00000-...0001`), deneme resmi ve sosyal bahisleri, bir trivia düellosu, bir günün tahmini ("E2E: Bugun kampuste kar yagar mi?"); kullanıcının test hesabı örnek alan adıyla doğrulanmış, iki görev ödülü almış (ikincisi +20 XP ile, Adım 10 XP denemesi) ve "Mor isim"i satın alıp kuşanmış.
- [18d] Geliştirme sunucusunda panel sayfalarında (ör. İstatistik) Next.js uyarısı: "`Date.now()` önceden çizim sırasında" (sol altta "1 Issue"). 18d'den önce de vardı (`git stash` ile doğrulandı), derleme geçiyor, sayfalar çalışıyor. Düzen katmanındaki `await connection()` düzen kaynaklı olanı giderdi; `createClient` içine koymak "Suspense dışında" hatası verdi. Çözüm: sayfa başına `await connection()` ya da `<Suspense>`.

## Kullanıcı kararı / aksiyonu bekleyenler

- **Canlıya geçiş** ([yayin](yayin.md) "Canlıya geçiş sırası"): canlı Supabase projesi; Auth'ta Site URL, Redirect URLs (`com.kampusbet.kampusbet://**`), Türkçe e-posta şablonları (`supabase/templates/`), **özel SMTP** (yerleşik mail saatte çok az gönderir); Android yükleme anahtarı (`keytool`) + `android/key.properties`; Play Console hesabı; admin için barındırma (ör. Vercel) ve alan adı; uygulama ikonu; inceleme için doğrulanmış demo hesap.
- **KVKK aydınlatma metni** (`mobile/assets/legal/kvkk_aydinlatma.txt`) taslak: veri sorumlusu, adres, iletişim e-postası, yurt dışına aktarım dayanağı (KVKK m. 9), mail sağlayıcısı ve güvenlik kaydı süresi doldurulmalı; yayından önce hukuk incelemesi (sıralamada gösterim için açık rıza gerekip gerekmediği dahil).
- **Kullanım koşulları taslağı** (`mobile/assets/legal/kullanim_kosullari.txt`, admin kopyası aynı kalmalı): işletmeci adı, iletişim e-postası, yetkili mahkeme doldurulmalı; **yaş sınırı** (18 varsayıldı) ve "bahis" kelimesi hukuk incelemesinde. Metin değişirse `AppInfo.termsVersion` ve "Sürüm:" satırı birlikte güncellenir.
- **Supabase Vault'a servis anahtarı**: `kampusbet_storage_service_key` adıyla (Dashboard > Project Settings > API Keys'teki secret key; SQL Editor'da `select vault.create_secret('<anahtar>', 'kampusbet_storage_service_key');`). Kampüs görevi fotoğraflarının 30 gün sonra silinmesi için gerekli. Canlı projede `private.storage_settings.project_url` de canlı adresle doldurulmalı.
- Kampüs görevi tavanları varsayıldı: yetkili görevinde en çok 100 SP / 50 XP, kişi başı günde 5 görev (`economy_settings`, SQL ile değişir).
- İstek sınırı rakamı: dakikada 60 yazma isteği varsayıldı (`economy_settings.api_write_limit_per_minute`).
- Gerçek okulun adı ve öğrenci mail alan adı (şimdilik "Örnek Üniversitesi" / `ogr.ornek.edu.tr`).
- Mail sağlayıcısı hesabı (öneri Brevo) ve API anahtarının Supabase Vault'a konması ([kimlik](kimlik.md)).
- `KARARLAR.md` açık öneriler: 6 ("bahis" adı riski), 7 (mağaza zorunlulukları), 8 (Android öncelik).
- Supabase Auth'ta sızdırılmış şifre koruması (HaveIBeenPwned) kapalı; advisors uyarıyor. Açmak panelden kullanıcının işi (Authentication ayarları; ücretsiz planda olmayabilir).
- **Başarım listesi ve ödülleri taslak** (25 başarım, 20–300 SP, 0–120 XP; KARARLAR "Başarımlar ve günlük ödül takvimi"); XP / ekonomi rakamlarıyla birlikte gözden geçirilecek. Değişiklik yalnızca `achievements` güncellemesidir.
- Resmi bahiste sabit oran mı havuz mu ("sonra tekrar bakarız").
- Ekonomi rakamları taslak: başlangıç SP, günlük ödül, sosyal / düello / tahmin sınırları, itiraz süresi, ihtar sınırı, **görev ödülleri (20–150 SP) ve market fiyatları (SP 250–600, SSP 80–150)**, **liderlik isabet eşiği (5 tahmin / hafta, 20 tüm zamanlar)**, **XP (giriş 10, doğru tahmin 15, günde en fazla 60; görev günlük 20 / haftalık 50; seviye adımı 100; Altın çerçeve 3. seviye, Kehanet Ustası 5. seviye)**. Adım 9-10 kuralları (KARARLAR "Görevler", "Market", "Liderlik ve istatistik", "XP ve seviye") varsayılan olarak uygulandı.
- **Yapılacak (kullanıcı, 2026-11-22): XP rakamları ve seviye kuralları birlikte yeniden ele alınacak.** Şu an varsayılan
  uygulanıyor (KARARLAR "XP ve seviye"). Konuşulacaklar: giriş / görev / doğru tahmin XP'si ve günlük sınır, seviye
  eğrisi (adım 100), hangi ürünün hangi seviyede açılacağı, seviyenin özellik de açıp açmayacağı (ör. sosyal bahis
  açmak için 2. seviye: yeni hesaplarla SP aktarmayı da zorlaştırır), eski kayıtlara geriye dönük XP verilip
  verilmeyeceği. Rakam değişikliği yalnızca `economy_settings` / ürün / görev güncellemesidir; seviye adımı değişirse
  mevcut seviyeler yeniden hesaplanmalı ([para](para.md)).
