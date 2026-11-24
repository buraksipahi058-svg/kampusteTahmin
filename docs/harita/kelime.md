# Bölge: Kampüs kelimesi (Adım 19)

Günde bir kampüs kelimesi; öğrenci sınırlı hakta (6) bulur, her tahminde harfler işaretlenir. Kural ve gerekçe:
KARARLAR "Kampüs kelimesi". Genel kalıplar: [veritabani](veritabani.md).

Kod: `20261124074445_kelime_oyunu_degerleri.sql` (enum: `kelime_yonet`, `word_reward`, `ledger_ref_type.word_puzzle`,
`xp_reason.word_puzzle`), `20261124074448_kelime_oyunu.sql`, `20261124074450_kelime_sozlugu.sql` (sözlük verisi).
Güvenlik kontrolü 3 düzeltmeleri ve ipucu: `20261124084204_kelime_guvenlik_ipucu.sql` (aşağıdaki tanımların geçerli
hali bu dosyada). Test: `23_kelime_oyunu.test.sql` (49), `24_kelime_guvenlik_ipucu.test.sql` (27). Testler buluttaki
gerçek kelimeleri işlem içinde 10 yıl geriye alır (geri alınır), yoksa bugünün gerçek kelimesi testi bozar.

## Veritabanı

- `word_puzzles`: okul (boş = bütün okullar, yalnızca süperadmin), gün (`puzzle_date`, İstanbul), `word_length`
  (4–8), giren. Gün başına okulda bir, genelde bir (`word_puzzles_day_key`). **Kelime burada yok.** RLS: süperadmin
  hepsini, okulunda `kelime_yonet` olan okulunun hepsini (ileri tarihliler dahil), doğrulanmış öğrenci okulunun ve
  genelin bugüne kadarkini görür.
- `private.word_answers` (bulmaca → kelime, isteğe bağlı ipucu 3–140 karakter) ve `private.word_dictionary`
  (18.849 kök kelime, 4–8 harf; admin'in girdiği kelimeler de eklenir): istemciye kapalı. `private.word_puzzle_viewers`:
  kelimeyi görmüş kişiler (giren, yönetim listesinde gören) — izni kalksa da o kelimeden ödül almaz.
  `word_puzzles.created_by` istemciye kapalı (kolon bazlı okuma). Kelimeler Türkçe büyük harf (`ABCÇDEFGĞHIİJKLMNOÖPRSŞTUÜVYZ`).
- `word_attempts` (bulmaca + kişi): tahminler, işaretler (`'20100'`: 2 doğru yerde, 1 başka yerde var, 0 yok),
  bulundu mu, bitiş, verilen SP / XP. RLS: yalnızca kişinin kendisi ve süperadmin (tahminler ipucudur).
- Ayarlar (`economy_settings`): `word_max_guesses` (6), `word_reward_sp` `{60,60,40,40,20,20}`, `word_reward_xp`
  `{20,20,15,15,10,10}` (n. tahminde bulana n. eleman; dizi uzunluğu hak sayısı kadar, SP > 0), `word_hint_after` (3;
  1 ile hak − 1 arası).
- Yardımcılar: `private.word_today()`, `normalize_word` (i → İ, ı → I, â → A, boşluk kırpılır), `word_puzzle_for(okul,
  gün)` (okula özel önce, yoksa genel), `word_marks(tahmin, kelime)` (önce doğru yerdekiler, kalan harfler kelimede
  kalan sayısı kadar 1 alır), `word_reward_blocked(okul)` (süperadmin; okul kelimesinde o okulda `kelime_yonet`).

## Fonksiyonlar

- `my_word_puzzle()` → kişinin bugünkü bulmacası (o gün başladığı varsa o, yoksa okulunki: `word_puzzle_for_user`)
  ve durumu (yoksa satır yok): uzunluk, hak, tahminler, işaretler, bitti / bulundu, ödül, ödül tablosu, `can_earn`,
  `has_hint`, `hint_after`, `hint` (yalnızca `hint_after` tahminden sonra ya da oyun bitince); **kelime yalnızca oyun
  bitince**. Doğrulanmamış `KB002`.
- `submit_word_guess(bulmaca, tahmin)` → işaretler, bulundu, bitti, kalan hak, SP, XP, (bittiyse) kelime, (zamanı
  geldiyse) ipucu. Yalnızca kişinin bugünkü bulmacası (`P0002`; günde tek oyun). Sıra: bulmaca satırı `FOR SHARE`
  (kelime düzenlemesi bitene kadar bekler) → bitmiş oyun `KB039` (sözlük sorgusu olarak kullanılamaz) → harf dışı
  `23514` → uzunluk `KB037` → sözlükte yok `KB038` (hak gitmez; cevap da sözlükte olduğu için cevap hakkında bilgi
  vermez) → deneme kilidi → işaret → ödül. Kilit sırası: bulmaca → deneme → bakiye → profil. Bulana
  `post_ledger(SP, 'word_reward', 'word_puzzle', bulmaca)`; XP ledger tetikleyicisinden (denemedeki `reward_xp`).
  Kelimeyi görebilen (süperadmin, okulunda `kelime_yonet`, kelimeyi görmüş) oynar, ödül almaz.
- Yönetim: `save_word_puzzle(id?, okul?, gün, kelime, ipucu?)` (okul boş → süperadmin; okul → `kelime_yonet`; geçmiş
  gün `23514`; bugün genel kelime varken okula bugün için yeni / bugüne taşınan kelime `KB041`; aynı güne ikinci
  `23505`; oynanmaya başlanmış `KB040`; okul değişmez; kelimeyi sözlüğe ve gireni görenlere ekler; denetim kaydı
  `word_puzzle_save` kelime ve ipucuyla), `delete_word_puzzle(id)` (oynanmamış; görmeyen için `P0002`;
  `word_puzzle_delete`), `list_word_puzzles()` (son 30 gün + ileri tarihli; kelime, ipucu, oynayan / bulan / ilk
  tahminde bulan; çağıranı görenlere ekler; yetkili genel kelimeyi görmez; izni olmayana `42501`).
- `export_my_data()` artık `private.export_my_data_base()`'i (eski tanım, biçim 2) çağırıp `word_puzzles` bölümünü
  ekleyen sarmalayıcı.

## Sözlük

Kaynak zemberek-nlp `master-dictionary.dict` (Apache 2.0, [UCUNCU_TARAF](../UCUNCU_TARAF.md)). Yeniden üretmek:
dosyayı indirip `python -I supabase/sozluk/sozluk_migration.py <dosya> <yeni migration>` (buluta gönderilmiş
migration düzenlenmez; değişiklik yeni migration olur). Yalnızca kök kelimeler: çoğul / çekimli biçimler (admin'in
girdikleri dışında) tahmin edilemez. Admin'in girdiği kelime sözlüğe eklenir: sözlük dışı cevap için "bu cevap mı?"
diye bedava deneme yolu kalmaz (Güvenlik kontrolü 3).

## Mobil ve admin

- Mobil: `games/word_screen.dart` (`/kampus-kelimesi`): tablo (hak × harf, kare kutular), işaret açıklaması, ödül
  özeti (`rewardSummary`), Türkçe Q klavye (Q W X yok; harfler bilinen en iyi işaretin renginde), uyarılar klavyenin
  üstünde satır içi (uyarı çubuğu alt sırayı örtüyordu), bitince sonuç kartı ve bulana kutlama. Renkler: doğru yeşil
  (`success`), var altın (`ssp`), yok gri. `games/word_data.dart` (`WordApi`, `wordPuzzleProvider`; testte
  `FakeWordApi`). Oyunlar'da dördüncü kart (bugünün kelimesi bitmediyse rozet). Öğreticinin Oyunlar sayfasında da var.
  İpucu: varsa önce "İpucu 3. tahminden sonra açılır.", sonra altın çerçeveli "İpucu: …" (`_HintLine`).
- Admin: `/kelimeler` (menüde "Kampüs kelimesi"; süperadmin ya da `kelime_yonet`): kapsam (süperadmin "Tüm okullar"
  da seçer), gün, kelime, isteğe bağlı ipucu; liste (Bugün rozeti, ipucu, oynayan / bulan / ilk tahminde bulan:
  sızdırma şüphesi için), oynanmamış ileri tarihliyi silme.
