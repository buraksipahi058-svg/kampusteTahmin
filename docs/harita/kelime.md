# Bölge: Kampüs kelimesi (Adım 19)

Günde bir kampüs kelimesi; öğrenci sınırlı hakta (6) bulur, her tahminde harfler işaretlenir. Kural ve gerekçe:
KARARLAR "Kampüs kelimesi". Genel kalıplar: [veritabani](veritabani.md).

Kod: `20261124074445_kelime_oyunu_degerleri.sql` (enum: `kelime_yonet`, `word_reward`, `ledger_ref_type.word_puzzle`,
`xp_reason.word_puzzle`), `20261124074448_kelime_oyunu.sql`, `20261124074450_kelime_sozlugu.sql` (sözlük verisi).
Test: `23_kelime_oyunu.test.sql` (49).

## Veritabanı

- `word_puzzles`: okul (boş = bütün okullar, yalnızca süperadmin), gün (`puzzle_date`, İstanbul), `word_length`
  (4–8), giren. Gün başına okulda bir, genelde bir (`word_puzzles_day_key`). **Kelime burada yok.** RLS: süperadmin
  hepsini, okulunda `kelime_yonet` olan okulunun hepsini (ileri tarihliler dahil), doğrulanmış öğrenci okulunun ve
  genelin bugüne kadarkini görür.
- `private.word_answers` (bulmaca → kelime) ve `private.word_dictionary` (18.849 kök kelime, 4–8 harf): istemciye
  kapalı. Kelimeler Türkçe büyük harf (`ABCÇDEFGĞHIİJKLMNOÖPRSŞTUÜVYZ`).
- `word_attempts` (bulmaca + kişi): tahminler, işaretler (`'20100'`: 2 doğru yerde, 1 başka yerde var, 0 yok),
  bulundu mu, bitiş, verilen SP / XP. RLS: yalnızca kişinin kendisi ve süperadmin (tahminler ipucudur).
- Ayarlar (`economy_settings`): `word_max_guesses` (6), `word_reward_sp` `{60,60,40,40,20,20}`, `word_reward_xp`
  `{20,20,15,15,10,10}` (n. tahminde bulana n. eleman; dizi uzunluğu hak sayısı kadar, SP > 0).
- Yardımcılar: `private.word_today()`, `normalize_word` (i → İ, ı → I, â → A, boşluk kırpılır), `word_puzzle_for(okul,
  gün)` (okula özel önce, yoksa genel), `word_marks(tahmin, kelime)` (önce doğru yerdekiler, kalan harfler kelimede
  kalan sayısı kadar 1 alır), `word_reward_blocked(okul)` (süperadmin; okul kelimesinde o okulda `kelime_yonet`).

## Fonksiyonlar

- `my_word_puzzle()` → bugünün bulmacası ve kişinin durumu (yoksa satır yok): uzunluk, hak, tahminler, işaretler,
  bitti / bulundu, ödül, ödül tablosu, `can_earn`; **kelime yalnızca oyun bitince**. Doğrulanmamış `KB002`.
- `submit_word_guess(bulmaca, tahmin)` → işaretler, bulundu, bitti, kalan hak, SP, XP, (bittiyse) kelime. Yalnızca
  kişinin bugünkü bulmacası (`P0002`); harf dışı `23514`; uzunluk `KB037`; sözlükte yok (ve kelimenin kendisi
  değil) `KB038` — hak gitmez; bitmiş oyun `KB039`. Deneme satırı kilitlenir (kilit sırası: deneme → bakiye →
  profil). Bulana `post_ledger(SP, 'word_reward', 'word_puzzle', bulmaca)`; XP ledger tetikleyicisinden (denemedeki
  `reward_xp`). Kelimeyi görebilen oynar, ödül almaz.
- Yönetim: `save_word_puzzle(id?, okul?, gün, kelime)` (okul boş → süperadmin; okul → `kelime_yonet`; geçmiş gün
  `23514`; aynı güne ikinci `23505`; oynanmaya başlanmış `KB040`; okul değişmez; denetim kaydı `word_puzzle_save`
  kelimeyle), `delete_word_puzzle(id)` (oynanmamış; görmeyen için `P0002`; `word_puzzle_delete`),
  `list_word_puzzles()` (son 30 gün + ileri tarihli, kelime, sözlükte mi, oynayan / bulan sayısı; yetkili genel
  kelimeyi görmez; izni olmayana `42501`).
- `export_my_data()` artık `private.export_my_data_base()`'i (eski tanım, biçim 2) çağırıp `word_puzzles` bölümünü
  ekleyen sarmalayıcı.

## Sözlük

Kaynak zemberek-nlp `master-dictionary.dict` (Apache 2.0, [UCUNCU_TARAF](../UCUNCU_TARAF.md)). Yeniden üretmek:
dosyayı indirip `python -I supabase/sozluk/sozluk_migration.py <dosya> <yeni migration>` (buluta gönderilmiş
migration düzenlenmez; değişiklik yeni migration olur). Yalnızca kök kelimeler: çoğul / çekimli biçimler tahmin
edilemez (günün kelimesi çekimliyse yalnızca kendisi kabul edilir; admin listesinde "Sözlükte yok" uyarısı).

## Mobil ve admin

- Mobil: `games/word_screen.dart` (`/kampus-kelimesi`): tablo (hak × harf, kare kutular), işaret açıklaması, ödül
  özeti (`rewardSummary`), Türkçe Q klavye (Q W X yok; harfler bilinen en iyi işaretin renginde), uyarılar klavyenin
  üstünde satır içi (uyarı çubuğu alt sırayı örtüyordu), bitince sonuç kartı ve bulana kutlama. Renkler: doğru yeşil
  (`success`), var altın (`ssp`), yok gri. `games/word_data.dart` (`WordApi`, `wordPuzzleProvider`; testte
  `FakeWordApi`). Oyunlar'da dördüncü kart (bugünün kelimesi bitmediyse rozet). Öğreticinin Oyunlar sayfasında da var.
- Admin: `/kelimeler` (menüde "Kampüs kelimesi"; süperadmin ya da `kelime_yonet`): kapsam (süperadmin "Tüm okullar"
  da seçer), gün, kelime; liste (Bugün, Sözlükte yok rozetleri, oynayan / bulan), oynanmamış ileri tarihliyi silme.
