# Tasarım (Adım 18)

Kaynak: Emil Kowalski'nin tasarım mühendisliği kuralları (github.com/emilkowalski/skills; özetin aslı
`emil-design-eng`, `review-animations/STANDARDS.md`, `apple-design`, `mobile-native`, `break-ui`). Alt adımlar:
18a mobil tasarım sistemi (`2d5e833`), 18b mobil ekranlar ve hareket, 18c ikon ve görsel uyumu (ikisi `a831471`), mor
fütüristik tema ve 18d admin paneli (commit yok), 18e kontrol.

## Kurallar (yeni ekran / bileşen yazarken)

- **Az ama anlamlı hareket.** Günde çok görülen şey (sekme geçişi, liste satırı, klavye) animasyonsuz. Hareket
  geri bildirim, yer değişimi, durum ya da nadir kutlama içindir. Liste satırlarına giriş animasyonu yok.
- **Süre / eğri** (`core/design_tokens.dart` `Motion`): basma 120 ms, küçük durum 160 ms, giriş 250 ms, çıkış
  200 ms (girişten hızlı); arayüz animasyonu 300 ms'yi geçmez (alt sayfa ve pencere hariç). Giriş / çıkış
  `Motion.easeOut` = cubic-bezier(0.23, 1, 0.32, 1), ekranda yer değiştirme `Motion.easeInOut`; ease-in hiç.
- **Basma:** özel yüzey (kart) `Pressable` ile %97'ye küçülür; Material düğmelerinde dalga yeter (ikisi birden yok).
  Hiçbir şey ölçek 0'dan başlamaz (0.9-0.97 + opaklık).
- **Haptik** (`core/haptics.dart`): seçim `selection`, gönderim / kabul `light`, önemli işlem `medium`, kazanç
  `success`; görüntüyle aynı karede, olay başına bir kez, tek geri bildirim olarak değil.
- **"Animasyonları azalt"** (`Motion.reduced`): ölçek / kayma yok, opaklık ve renk kalır.
- **Durumlar** (`core/state_views.dart`): yükleniyor `LoadingView`, boş `EmptyView(text, icon)`, hata
  `ErrorView(what: 'X alınamadı.', error, onRetry)` (ham hata yok, `userMessage`). Her liste boş durumunu gösterir.
- **Sayılar:** değişen sayılar (bakiye, oran, havuz) sabit genişlikli rakam (`tabular()`); tutarlar
  `formatAmount` (1.050).
- **En kötü veriyle dene:** uzun isim, 0 / 1.000.000 SP, 320 dp genişlik, %200 yazı, karanlık mod.

## Tema (`core/app_theme.dart`): mor, fütüristik, koyu öncelikli

- Kimlik (kullanıcı kararı, 18c sonrası): **canlı mor** (`brandSeed` #7C3AED) + **neon camgöbeği** vurgu
  (`brandAccent` #22D3EE). Uygulama **koyu açılır** (`themeMode: ThemeMode.dark`); açık tema da mor, tanımlı kalır.
- Koyu şema elle (`_darkScheme`): gece moru zemin #0B0914, katman katman mor paneller (surfaceContainer*), ana renk
  #A78BFA, seçili parça / çip kabı mor (#2E2266; camgöbeği kap kullanılmaz, yalnızca vurgu).
- `AppColors` (`context.appColors`): `ssp` altın, `success` neon yeşil, `accent` camgöbeği, `glow` mor ışıltı,
  `brandGradient` mor → camgöbeği.
- Kart = panel: ince `outlineVariant` kenarlık, gölgesiz (koyu zeminde gölge görünmez); pencere ve alt sayfa da
  kenarlıklı panel. Ana sekmelerin arkasında `AppBackdrop` (sol üst mor, sağ alt camgöbeği çok hafif ışık hüzmesi;
  durağan, yalnızca sekmelerde: açılan ekranlar düz zemin, geçişte üst üste binmesin).
- Işıltı yalnızca öne çıkan şeyde: ana ton `IconBadge` (degrade + ışıltı), seçilen / kazanan bahis seçeneği.
- Sistem yazı tipi; başlıklar kalın ve sıkı, grup başlıkları aralıklı büyük harf (mor).
- `readableNameColor` / `readableOn`: sunucudan gelen kozmetik isim rengi zeminde en az 3:1 okunur.
- AppBar başlık stili temada verilmez (yazı boyutları dile göre sonradan eklenir; verilirse boyutsuz kalır).
- Ölçüler: `Space` (4, 8, 12, 16, 24, 32), `Radii` (8, 12, 16, 24).

## Ekranlar (18b)

- **Bahis seçeneği** `bets/bet_option_button.dart` `BetOptionButton`: tam genişlikte dokunulabilir yüzey (dalga +
  seçim titreşimi), sağda kalın hizalı oran / havuz; havuzlu bahiste arkada pay çubuğu; kazanan yeşil + kupa,
  kişinin seçtiği çerçeveli, hakemin önerdiği tokmaklı. Resmi, sosyal ve günün tahmini kartları bunu kullanır;
  kart başlığı `BetCardHeader` (durum saat / kilit simgeli), sonuç `BetResultText` (kazandıysa yeşil).
- **Yatırım alt sayfası:** tutarlar 10 / 25 / 50 / 100 çipleri (en az / en fazla tutar ve bakiye içinde), olası
  kazanç yeşil ve hizalı, yatırım yapılınca hafif titreşim.
- **Düello oyunu:** doğru cevap istemcide yok, o yüzden doğru / yanlış rengi gösterilmez (cevap anahtarı sızmasın);
  seçilen şık bir kare vurgulanır + seçim titreşimi, sonraki soru 250 ms kayarak / solarak gelir (azaltılmışta
  yalnız solma); eski sorunun ya da yeni soru çizilmeden gelen dokunuş yok sayılır (`_choose(soru, şık)`).
- **Kutlama** `core/celebration.dart` `showCelebration`: seviye atlama, QR görevi tamam, fotoğraf gönderildi;
  %92'den ölçeklenip solarak 250 ms, başarı titreşimi (fotoğrafta ödül henüz yok: hafif titreşim). Başarım ve
  günlük ödül alınınca başarı titreşimi.
- **Bakiye:** değişince 400 ms sayım (yalnızca değişince; azaltılmışta yok).
- **Profil:** SP / SSP / seri şeridi; gruplar İlerleme (seviye, görevler, başarımlar), İstatistik, Hesap (okul
  maili doğrulandıysa, şifre, gizlilik). Doğrulanmamışsa "Okul mailini doğrula" en üstte.
- **Liderlik:** ilk üç büyük madalya, kendi satırın renkli zemin + çerçeve, değer kalın ve hizalı.
- **Büyük yazı (%200):** üst çubuktaki zil, hediye ve bakiye ile oyun kartı rozeti en çok 1,3 kat büyür
  (`MediaQuery.withClampedTextScaling`); yoksa ekran başlığı itiliyordu. İçerik yazıları tam büyür.

## İkon ve görsel (18c)

- **Tek ikon ailesi:** Material Symbols Rounded (`material_symbols_icons`, `Symbols.x_rounded`). Varsayılan çizgi;
  seçili sekme, doğrulandı, kazanan kupası, tamamlandı işaretleri `fill: 1`. `Icons.*` kullanılmaz.
- **Arayüzde emoji yok:** kutlama penceresi ve başlıklar `IconBadge` (renkli daire + dolu ikon; ton yeşil / altın /
  nötr), boş ve hata görünümü nötr rozet, liderlik ilk üç `RankBadge` (altın / gümüş / bronz numara), günlük ödül
  takviminde para / hediye ikonları, başarım haberinde kupa ikonu.
- **Başarımlar:** veritabanındaki emoji gösterilmez; `AchievementBadge` (kademe renginde halka + başarıma özel ikon,
  bilinmeyen anahtarda kategori ikonu; kazanılmamış gri, gizli kilit) `achievements/achievement_badge.dart`.
- **İçerik emojisi** (kampüs görevi simgesi, market rozeti / unvanı): `EmojiToken` / `CosmeticPreview` aynı boyutta
  yuvarlatılmış kare jeton içinde; isim rengi önizlemesi okunur renkte.
- **Uygulama ikonu ve logo:** mor → gece moru degrade zemin, sağ altta camgöbeği hüzme, beyaz yuvarlak uçlu "K"
  monogramı, ışıldayan neon camgöbeği nokta.
  `mobile/tool/make_icon.py` (PIL) `assets/brand/` altına üretir; `dart run flutter_launcher_icons` Android
  (uyarlanabilir: degrade arka + monogram ön katman) ve iOS ikonlarını yazar. Araç iOS
  `project.pbxproj`'de `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS`'ı bozar: geri alınır.
  Logo (`BrandLogo`) giriş ve yükleniyor ekranlarında.

## Testler

`mobile/test/app_test.dart` metinlere ve düğme türlerine (FilledButton, OutlinedButton, NavigationBar) dayanır:
tasarım değişirken Türkçe metinler ve düğme türleri korunur ya da test birlikte güncellenir. Tema testleri:
"tema: açık ve karanlık kurulur", "kozmetik isim rengi ... okunur", "hata görünümü ...".

## Admin paneli (18d)

- **Kimlik mobille aynı:** panel her zaman koyu (`<html class="dark">`, `@custom-variant dark`), gece moru zemin,
  sol üstte mor, sağ altta camgöbeği durağan ışık hüzmesi (`globals.css` `body`).
- **Renk tokenları** (`admin/src/app/globals.css` `@theme`): `bg`, `panel` / `panel-2` / `panel-3`, `line` /
  `line-strong`, `fg`, `muted`, `primary` / `primary-hover` / `primary-soft` / `primary-fg`, `accent`, `success`,
  `danger` / `danger-strong`, `warning`. Sayfalarda `text-muted`, `border-line`, `bg-panel`, `text-danger` gibi
  kullanılır; `zinc-*`, `red-*`, `green-*` ham renk yok (istisna: QR görseli beyaz zeminde, okunsun diye).
- **Ortak parçalar** `components/kit.tsx` (sunucuda da çalışır): `buttonClass(ton, boyut)` (primary / secondary /
  danger / ghost; basınca %97, 150 ms ease-out, odak halkası), `inputClass`, `Panel`, `PageHeader`, `Badge`,
  `EmptyState`. Panel kutusu: `rounded-xl border border-line bg-panel/90 p-4`.
- **Yan menü** `components/side-nav.tsx`: sayfa ikonu (lucide-react) + ad; etkin sayfa mor zemin + camgöbeği sol
  çizgi. Masaüstünde sabit sol sütun (altta kişi ve çıkış), dar ekranda üstte yatay kayan şerit.
- **Bildirim:** `ActionForm` başarıda formdaki mesajın yanında köşede kısa bildirim de gösterir (sonner, sağ alt).
- **Tablolar:** başlıklar küçük, büyük harf, soluk; hücreler arasında boşluk (`@layer base`), sayılar sabit
  genişlikli.
- Hareket mobilin eğrileriyle aynı (`--ease-out`, `--ease-in-out`); sayfa geçişi animasyonsuz.

