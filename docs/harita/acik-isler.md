# Açık işler

Adımlardan kalan **denenmemiş** şeyler, **eksikler**, **çözülmemiş sorunlar** ve **kullanıcı kararı / aksiyonu
bekleyenler**. Her adımın sonunda güncellenir: yeni madde eklenir, çözülen silinir. Madde başındaki köşeli
parantez ortaya çıktığı adım.

## Denenmemiş (kod var, gerçek ortamda doğrulanmadı)

- [6-9] **Admin panelinde giriş sonrası tüm ekranlar** (resmi bahisler, yetkiler, bakiye, itirazlar, trivia soruları, günün tahmini, görevler, market) tarayıcıda denenmedi. Gerekli: kullanıcının kendi şifresiyle girmesi ve hesabının yetkili ya da süperadmin olması. Arkalarındaki veritabanı fonksiyonları pgTAP ve SQL ile denendi.
- [7] **Mobilde itiraz etme ve moderatör kararının** uygulama içinden uçtan uca akışı (tek gerçek hesap hakem olduğu için itiraz edemedi). pgTAP ve widget testleriyle sınandı.
- [8] Mobilde **düelloyu kabul etme** (uygulamadaki "Kabul et") ve **süre bitince kendiliğinden gönderme** uçtan uca denenmedi; denemede rakip SQL ile kabul etti. Kabul, pgTAP ve widget testiyle; süre aşımı pgTAP'le sınandı.
- [8] Düello (`kampusbet_trivia_duellolari`) ve günün tahmini (`kampusbet_gunun_tahmini`) zamanlanmış işlerinin bulutta kendiliğinden çalıştığı gözlenmedi (sosyal bahis işi gözlendi; aynı düzen). pgTAP fonksiyonları doğrudan çağırdı.
- [8] Günün tahmininde **birden çok kişiyle havuz paylaşımı** uygulamada denenmedi; emülatör denemesinde tek katılımcı vardı (kazanınca kendi 30 SP'si döndü). Çok kişili dağıtım pgTAP'te sınandı.
- [9] Uygulamada **SSP vitrininden satın alma**, kuşanılan ürünü **çıkarma**, **çerçeve / unvan / rozet**in profilde görünmesi ve **sezonluk görev** denenmedi (emülatörde SP ile "Mor isim" alındı ve kuşanıldı, bir günlük görev ödülü alındı). pgTAP ve widget testleriyle sınandı.
- [5] **Okul maili kodunun gerçek mail olarak gitmesi** (Brevo yolu). Yalnızca isteğin pg_net kuyruğuna girdiği test edildi; gerçek gönderim yok.
- [4] **iOS derlemesi** hiç denenmedi (Mac ya da bulut CI gerekir).

## Eksik (yapılmadı, sonraya bırakıldı)

- [8] Mobilde **belirli bir kişiye meydan okuma** yok (hep okula açık); veritabanı destekliyor (`p_invited_id`).
- [8] Düello bitince **doğru cevapları gösterme** yok (oyuncu yalnızca skorunu görür).
- [8] Admin'de trivia sorusunu **düzenleme** yok (yalnızca ekle, aç / kapa); `save_trivia_question` düzenlemeyi destekliyor.
- [8] Günün tahmini için okul başına "günde bir soru" sınırı ya da ileri tarihli planlama yok; yetkili istediği kadar soru açabilir.
- [7] **Grup oluşturma / gruba davetle katılma** yok; özel kapsamlı (grup) bahis veritabanında var ama oluşturulamıyor.
- [7] Mobilde sosyal bahiste **başka hakem seçme** yok (hep açan); veritabanı destekliyor.
- [7] Admin'de **sonuç girilmemiş / sorunlu sosyal bahisleri** listeleme ve iptal ekranı yok (`cancel_social_bet` var).
- [7] **Bildirim** yok: itiraz gelince hakeme / moderatöre, sonuç kesinleşince katılanlara.
- [7] Hakem ihtarını geri alma / af mekanizması yok.
- [2-7] Aynı kişilerin sık eşleşmesini (SP aktarma şüphesi) izleme yok (KARARLAR öneri 1'deki kalan risk).
- [6] Resmi bahiste oran sonradan değiştirilemiyor (yalnızca açarken).
- [4] Mail onay linki uygulamayı açmıyor (deep link yok; Supabase Site URL'sine gidiyor).
- [2-9] XP / seviye hiçbir yerde artmıyor; görevler de XP vermiyor.
- [9] Kuşanılan kozmetikler yalnızca kişinin kendi profilinde görünüyor; başkalarının görebileceği yer (liderlik tablosu, bahis kartları) Adım 10'da. Veritabanı okul arkadaşlarına açık.
- [9] Market'te tema, banner, emote ve bahis "flair"i türleri yok (v1: unvan, rozet, çerçeve, isim rengi); stoklu / sınırlı sayıda ürün yok.
- [9] Admin'de ürünün kaç kez satıldığı ve görevin kaç kişi tarafından tamamlandığı görünmüyor (analitik).
- [9] Görev türleri sabit beş eylem; "farklı kümede bahis aç" gibi ölçütler yok (grup / küme oluşturma da yok).
- [11] Hesap silme (soft delete + anonimleştirme), KVKK aydınlatma metni.

## Çözülmemiş sorunlar / bilinen pürüzler

- [0] `npx supabase migration new` bir kez çıkmadan takıldı; stdin kapatılıp zaman aşımıyla çalıştırılınca sorun yok (`< /dev/null`, `timeout 60`). Supabase CLI 2.121 kullanılıyor, 3.x çıktı; yükseltilmedi.
- [0-6] `npm install` sırasında `unrs-resolver` için "allow-scripts" uyarısı (npm 11 kurulum betiğini onaylamadan çalıştırmıyor). Lint şu an çalışıyor; ileride ESLint çözümleyicisi sorun çıkarırsa `npm approve-scripts unrs-resolver`.
- [8] `npx supabase db push --include-seed` ikinci kez çalışınca seed dosyasının özetini güncelledi ama satırları yazmadı (trivia soruları). Seed `npx supabase db query --linked -f supabase/seed.sql` ile çalıştırıldı (dosya tekrar çalıştırılabilir). Sebep bulunmadı.
- [9] Bash aracında `<<'EOF'` heredoc'u içindeki ters bölü (`\n`, `\'`) dosyaya yazılırken tek ters bölüye ya da gerçek satır sonuna dönüşüyor (Python ile dosya düzenlerken iki kez Dart metnini bozdu). Ters bölü gereken düzenlemelerde Edit aracını kullan.
- [8] Windows PowerShell 5.1, BOM'suz `.ps1` dosyalarındaki Türkçe karakterleri bozuk okuyor (emülatör otomasyon betiğinde görüldü); betikleri UTF-8 BOM'lu kaydet ya da komut satırından ver.
- [5] Supabase ücretsiz plan bir hafta işlem olmazsa projeyi duraklatıyor; açmak kullanıcının işi ([ortam](ortam.md)).
- [1] Supabase advisors `public.rls_auto_enable()` için uyarı veriyor (Supabase'in kendi tetikleyicisi; zararsız, dokunulmuyor).
- [1-8] Advisors her istemci RPC'si için "authenticated `SECURITY DEFINER` çağırabiliyor" uyarısı veriyor: tasarım gereği (her fonksiyon yetkiyi içeride denetler, pgTAP ret testleri var). Adım 11 denetiminde topluca gözden geçirilecek.
- [6-9] Bulutta deneme verisi duruyor: "Test Yetkili" profili (`e2e00000-...0001`), deneme resmi ve sosyal bahisleri, bir trivia düellosu, bir günün tahmini ("E2E: Bugun kampuste kar yagar mi?"); kullanıcının test hesabı örnek alan adıyla doğrulanmış, bir görev ödülü almış ve "Mor isim"i satın alıp kuşanmış.

## Kullanıcı kararı / aksiyonu bekleyenler

- Gerçek okulun adı ve öğrenci mail alan adı (şimdilik "Örnek Üniversitesi" / `ogr.ornek.edu.tr`).
- Mail sağlayıcısı hesabı (öneri Brevo) ve API anahtarının Supabase Vault'a konması ([kimlik](kimlik.md)).
- Admin panelini denemek için hesabının yetkili / süperadmin yapılması (süperadmin resmi bahse yatıramaz).
- `KARARLAR.md` açık öneriler: 6 ("bahis" adı riski), 7 (mağaza zorunlulukları), 8 (Android öncelik).
- Supabase Auth'ta sızdırılmış şifre koruması (HaveIBeenPwned) kapalı; advisors uyarıyor. Açmak panelden kullanıcının işi (Authentication ayarları; ücretsiz planda olmayabilir).
- Resmi bahiste sabit oran mı havuz mu ("sonra tekrar bakarız").
- Ekonomi rakamları taslak: başlangıç SP, günlük ödül, sosyal / düello / tahmin sınırları, itiraz süresi, ihtar sınırı, **görev ödülleri (20–150 SP) ve market fiyatları (SP 250–600, SSP 80–150)**. Adım 9 kuralları (KARARLAR "Görevler", "Market") varsayılan olarak uygulandı.
- Adım 7, 8 ve 9 commit'i (kullanıcı commit istemedikçe yapılmıyor).
