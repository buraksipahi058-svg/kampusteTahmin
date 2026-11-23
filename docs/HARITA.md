# KampüsBet — Proje Haritası

Amaç: projeyi **en az bağlam harcayarak** anlamak. Bu dosyayı oku, sonra yalnızca görevin
gerektirdiği bölgeleri aç. Kod dosyalarını baştan sona okuma; bölge dosyası nereye bakacağını söyler.

## Şu an

- **Commit:** yalnızca kullanıcı onay verince, yalnızca yerel (push yok). Adım 7-9 `f45f3dc`'de; Adım 10 + XP / seviye `0ca9789`'da, Adım 11 `2fa4c08`'de, Adım 12 `ae29d5e`'de, Adım 13 `c205879`'da, Adım 14 `e62ac52`'de; Adım 15 `d1fbcb0`, 16 `820159b`, 17 `5a5cb8a`, 17a `5a82a51`, 17b `7111dc2`, güvenlik kontrolü 2 `d937b4f`, Oyunlar menüsü `d43c5c9`, 18a `2d5e833`, 18b-18c `a831471`, mor tema + 18d `776e171` (adım başına ayrı commit; ara commit'lerde de mobil analiz, Flutter testleri ve admin tip kontrolü temiz).
- **Son tamamlanan (commit yok):** Adım 18e, tasarımın son kontrolü ([tasarim](harita/tasarim.md) "Son kontrol"): başarı / tamamlandı / doğru işaretleri mor yerine yeşil, sayı rozetleri oka binmiyor (`CountChevron`), bakiyeli üst çubukta başlık kesilmek yerine küçülüyor (`AppBarTitle`, %200 yazıda da), üç ekranda ortak hata görünümü, admin'de dar ekranda etkin sayfa görünür; 72 Flutter testi, analiz ve admin lint temiz, release APK emülatörde gezildi. Önceki (`776e171`): mor tema + Adım 18d, admin paneli mobille aynı mor, koyu kimliğe geçti ([tasarim](harita/tasarim.md) "Admin paneli"): renk tokenları (`globals.css`), ortak parçalar (`components/kit.tsx`), sol yan menü (lucide ikonları, etkin sayfa vurgusu), köşe bildirimi (sonner), giriş ekranında logo; 15 panel sayfası ve ayrıntı sayfaları süperadmin girişiyle tarayıcıda açıldı (form gönderilmedi), derleme ve lint temiz. Ondan önce mobil tasarım mor ve fütüristik oldu (koyu açılır, gece moru zemin, ince kenarlıklı paneller, mor → camgöbeği degrade rozetler, ışıltılar, mor uygulama ikonu ve logo; [tasarim](harita/tasarim.md) "Tema"). Önceki (`a831471`): Adım 18c, ikon ve görsel uyumu: bütün ikonlar Material Symbols Rounded, arayüzde emoji yerine ikon rozetleri, başarımlar kademe halkalı ikon rozetleri, içerik emojileri tek tip jetonda, yeni uygulama ikonu (yeşil "K" + altın nokta) ve giriş / yükleniyor logosu. Ondan önce Adım 18b, mobil ekranlar ve hareket ([tasarim](harita/tasarim.md) "Ekranlar"): bahis seçenekleri dokunulabilir düğme (oran / havuz, pay çubuğu, kazanan / seçilen), yatırımda hızlı tutar çipleri, düelloda seçim vurgusu + geçiş (cevap anahtarı sızmadan), kutlama pencereleri ve titreşimler, bakiye sayımı, Profil grupları, liderlikte ilk üç ve kendi satırın, %200 yazıda üst çubuk düzeltmesi; 72 Flutter testi, telefona kuruldu. Önceki: 18a (`2d5e833`).
- **Bulutta deneme verisi:** giriş yapamayan "Test Yetkili" profili (`e2e00000-...0001`), sonuçlanmış resmi ve sosyal deneme bahisleri, bir trivia düellosu, bir günün tahmini; kullanıcının test hesabı `deneme@ogr.ornek.edu.tr` ile doğrulanmış (820 SP, 20 XP, "Mor isim" kuşanılı); ikinci test hesabı `test1@ogr.ornek.edu.tr` **süperadmin** (2026-11-23; admin paneline bununla girilir, resmi bahse yatıramaz; giriş e-postası da okul maili de bu; Supabase uydurma alan adıyla kayda izin vermediği için panelden "Auto Confirm" ile açıldı, okul maili veritabanında doğrulandı, şifre kullanıcıda); oynamak için üçüncü hesap `test2@ogr.ornek.edu.tr` (öğrenci, kullanıcı panelden açtı, okul maili veritabanında doğrulandı). Seed'de 5 genel görev, 8 genel ürün.
- **Sıradaki:** Adım 18 bitti; telefonda kullanıcının gözle bakması. Ayrıca fotoğraf silme için Vault anahtarı (kullanıcının işi, [yayin](harita/yayin.md)). Sonrası öneri: gruplar, izleme / analitik. Ayrıca kullanıcının canlıya geçiş adımları ([yayin](harita/yayin.md) "Canlıya geçiş sırası"); uygulama tarafında kalanlar [acik-isler](harita/acik-isler.md)'de (bildirimler, ikon, admin panelinin girişle denenmesi, eksik özellikler).
- **Açık işler** (denenmemiş, eksik, çözülmemiş, kullanıcıdan beklenen): [harita/acik-isler.md](harita/acik-isler.md).

| # | Adım | Durum | Commit |
|---|---|---|---|
| 0 | Ortam + iskelet | Bitti | `72b41cf` |
| 1 | Kümeler, profiller, yetkiler, RLS | Bitti | `af1c23a` |
| 2 | Para çekirdeği | Bitti | `1ff2cfb` |
| 3 | Bahis çekirdeği | Bitti | `ecc3be0` |
| 4 | Mobil temel | Bitti | `820d315` |
| 5 | Okul maili doğrulama | Bitti | `eea1448` |
| 6 | Resmi SSP bahisler + admin paneli | Bitti | `eea1448` |
| 7 | Sosyal havuz (hakem, itiraz) | Bitti | `f45f3dc` |
| 8 | Mini oyunlar (trivia düellosu, günün tahmini) | Bitti | `f45f3dc` |
| 9 | Görevler + market | Bitti | `f45f3dc` |
| 10 | Liderlik + istatistik, XP / seviye | Bitti | `0ca9789` |
| 11 | Güvenlik denetimi, hesap silme, KVKK | Bitti | `2fa4c08` |
| 12 | Yayına hazırlık (linkler, şifre, Android imza, mağaza sayfaları) + kalite kontrolü | Bitti | `ae29d5e` |
| 13 | Yönetim ve güvenlik eksikleri (istek bekçisi, yasaklama, ihtar, oran, admin ekranları) | Bitti | `c205879` |
| 14 | Gizlilik (sıralamadan çıkma, veri dışa aktarma, istek sınırı, kullanım koşulları) | Bitti | `e62ac52` |
| 15 | Mobil eksikler (kişi seçme, düello cevapları, kozmetikli isimler, başkasının profili, geçmiş, kutlama) | Bitti | `d1fbcb0` |
| 16 | Başarımlar (+ admin yönetimi, haber) + günlük ödül takvimi | Bitti | `820159b` |
| 17 | Uygulama içi bildirimler | Bitti | `5a5cb8a` |
| 17a | Kampüs görevleri: QR | Bitti | `5a82a51` |
| 17b | Kampüs görevleri: fotoğraf, onay, 30 gün silme | Bitti | `7111dc2` |
| G2 | Genel güvenlik kontrolü 2 (bağımsız inceleme, 8 düzeltme) | Bitti | `d937b4f` |
| 18a | Tasarım: mobil tasarım sistemi (tema, karanlık mod, ortak durumlar) | Bitti | `2d5e833` |
| 18b | Tasarım: mobil ekranlar ve hareket (bahis seçenekleri, düello, kutlama, profil, liderlik) | Bitti | `a831471` |
| 18c | Tasarım: ikon ve görsel uyumu (Material Symbols Rounded, emojisiz arayüz, başarım rozetleri, uygulama ikonu ve logo) | Bitti | `a831471` |
| 18-mor | Tasarım: mor ve fütüristik tema (mobil: koyu açılış, paneller, degrade rozetler, ışıltı, mor ikon ve logo) | Bitti | `776e171` |
| 18d | Tasarım: admin paneli (mor koyu tema, renk tokenları, yan menü, lucide ikonları, köşe bildirimi) | Bitti | `776e171` |
| 18e | Tasarım: son kontrol (renk anlamı, rozet, başlık, hata görünümü, admin dar ekran) | Bitti | commit yok |

## Görev → ne okunur

| Görev | Oku | Okuma |
|---|---|---|
| Mobil ekran / akış (Adım 4) | [mobil](harita/mobil.md) + gerekirse ilgili konu bölgesi (kimlik / para / bahis) | migration'lar, testler |
| Tasarım, tema, hareket, ortak durum bileşenleri (Adım 18) | [tasarim](harita/tasarim.md) | |
| Admin ekranı (Adım 6) | [admin](harita/admin.md) + ilgili konu bölgesi | migration'lar |
| Yeni SQL tablo / fonksiyon / RLS | [veritabani](harita/veritabani.md) + konu bölgesi + [testler](harita/testler.md) | eski test dosyalarının tamamı |
| Okul, profil, yetki, okul maili (Adım 5) | [kimlik](harita/kimlik.md) | |
| Bakiye, ödül, market, görev (Adım 9), XP / seviye, başarımlar ve günlük ödül takvimi (Adım 16) | [para](harita/para.md) | |
| Resmi / sosyal / mini oyun bahisleri (Adım 6-8) | [bahis](harita/bahis.md) | |
| Liderlik, kişisel istatistik, admin okul özeti (Adım 10) | [liderlik](harita/liderlik.md) | |
| Bildirimler, kampüs görevleri (QR, fotoğraf, onay) (Adım 17-17b) | [kampus](harita/kampus.md) | |
| Güvenlik kuralları, hesap silme, KVKK metni (Adım 11), istek bekçisi / sınırı, gizlilik, kullanım koşulları (Adım 13-14) | [guvenlik](harita/guvenlik.md) | |
| Canlıya geçiş, Android yayın derlemesi, e-posta linkleri, mağaza (Adım 12) | [yayin](harita/yayin.md) | |
| Komut çalıştırma, araç, emülatör, CLI hatası | [ortam](harita/ortam.md) | |
| Test yazma / çalıştırma | [testler](harita/testler.md) | |
| Denenmemiş / eksik / çözülmemiş ne var, kullanıcıdan ne bekleniyor | [acik-isler](harita/acik-isler.md) | |
| Bir kararın gerekçesi | `docs/KARARLAR.md`'de ilgili satırı ara | dosyanın tamamı |
| Ürün vizyonu (ekran haritası, oyunlaştırma) | `docs/MIMARI.md`'nin ilgili bölümü | dosyanın tamamı |

Bölge dosyaları 30-60 satırdır; bir görev genelde 1-3 bölge ister.

## Haritayı güncel tutmak

Bir adım bitince yalnızca: bu dosyadaki "Şu an" ve adım tablosu, değişen bölgenin dosyası.
Yeni karar `KARARLAR.md`'ye tek satır. Geçmiş kaydı tutulmaz; git log yeter.
