# Tasarım (Adım 18)

Kaynak: Emil Kowalski'nin tasarım mühendisliği kuralları (github.com/emilkowalski/skills; özetin aslı
`emil-design-eng`, `review-animations/STANDARDS.md`, `apple-design`, `mobile-native`, `break-ui`). Alt adımlar:
18a mobil tasarım sistemi (bitti), 18b mobil ekranlar ve hareket, 18c admin, 18d kontrol.

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

## Tema (`core/app_theme.dart`)

- `buildAppTheme(Brightness)`: tohum `brandSeed` (koyu yeşil), açık + karanlık (`themeMode` sistemden). Sistem yazı
  tipi; başlıklar kalın (w700, titleMedium w600) ve sıkı harf aralıklı.
- Kart: yuvarlak 16, açıkta yumuşak gölge, karanlıkta `surfaceContainer`; girdiler tek tip dış çizgili (12);
  snackbar yüzen; alt sayfalar tutamaklı; pencere köşesi 24.
- `AppColors` (ThemeExtension, `context.appColors`): `ssp` altın (SSP simgesi), `success`; açık / karanlık ayrı.
- `readableNameColor` / `readableOn`: sunucudan gelen kozmetik isim rengi zeminde en az 3:1 okunur.
- AppBar başlık stili temada verilmez (yazı boyutları dile göre sonradan eklenir; verilirse boyutsuz kalır).
- Ölçüler: `Space` (4, 8, 12, 16, 24, 32), `Radii` (8, 12, 16, 24).

## Testler

`mobile/test/app_test.dart` metinlere ve düğme türlerine (FilledButton, OutlinedButton, NavigationBar) dayanır:
tasarım değişirken Türkçe metinler ve düğme türleri korunur ya da test birlikte güncellenir. Tema testleri:
"tema: açık ve karanlık kurulur", "kozmetik isim rengi ... okunur", "hata görünümü ...".
