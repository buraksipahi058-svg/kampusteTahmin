# Kararlar

Bu dosya `MIMARI.md`'nin yanında yaşar: kesinleşen kararları ve henüz onay bekleyen önerileri tutar. Bir öneri onaylanınca "Kesinleşen" bölümüne taşınır, gerekiyorsa `MIMARI.md` de güncellenir.

## Kesinleşen kararlar

| Tarih | Konu | Karar |
|---|---|---|
| 2026-10-20 | Flutter geliştirme ortamı | Windows'a kurulur (Flutter SDK + Android Studio) |
| 2026-10-20 | Supabase geliştirme ortamı | Supabase Cloud (ücretsiz plan, Frankfurt). Şema değişiklikleri `supabase/migrations` altında migration olarak tutulur ve CLI ile buluta gönderilir; panelden elle şema değişikliği yapılmaz. (İlk karar host 192.168.1.13 idi; host erişilemez olunca değiştirildi.) |
| 2026-10-20 | Admin paneli | Next.js, Windows'ta çalışır. Secret key kullanmaz; yetki kontrolü veritabanında |
| 2026-10-20 | Repo | Yalnızca yerel git; GitHub sonra |

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

1. **Kullanıcılar arası SP/SSP transferi yok.** Transfer olursa SP dışarıda gerçek parayla satılır ve "gerçek para yok" ilkesi fiilen bozulur. Düello / sosyal havuzla bilerek kaybedip SP aktarma, düşük limit ve aynı kişilerin sık eşleşmesinin izlenmesiyle sınırlanır.
2. **Bahse katılmak da okul maili doğrulaması ister**, yalnızca bahis açmak değil. Bir okul maili yalnızca bir hesaba bağlanır. Aksi halde doğrulanmamış hesaplarla başlangıç SP'si ve günlük ödül toplanıp ana hesaba akıtılabilir.
3. **Para hareketleri yalnızca sunucu fonksiyonlarıyla.** İstemci ledger / wagers / balances tablolarına doğrudan yazamaz. İşlem sırasında bakiye satırı kilitlenir, bakiye negatife düşemez.
4. **Mini oyunlarda kontrol sunucuda:** trivia'nın doğru cevabı istemciye gitmez, cevap ve süre sunucuda kontrol edilir; reflex oyunu SP'siz (yalnızca skor); zar / çark sonucu sunucuda üretilir.
5. **v1'de düello = trivia düellosu** (aynı soruları çözen iki kişi). Gerçek dünya olayına bağlı düello Tip-2 sosyal havuz sayılır.
6. **İsim ve "bahis" dili** mağaza incelemesinde ve okullar nezdinde risk taşır; "tahmin" dili düşünülebilir. Görünen ad kodda tek bir yerde tutulur. Yayın öncesi hukuki görüş alınmalı.
7. **Mağaza zorunlulukları:** uygulama içinden hesap silme (ledger silinmez, kullanıcı anonimleştirilir) ve KVKK aydınlatma metni. Veri Supabase'in Frankfurt bölgesinde (yurt dışı) tutulduğu için metin yurt dışına aktarımı da kapsamalı.
8. **v1 Android öncelikli.** iOS derlemesi Mac ya da bulut CI ister.

## İlgili adımda çözülecek ayrıntılar

- Pari-mutuel: kazanan seçeneğe kimse yatırmadıysa herkese iade; tam sayı bölmeden kalan artığın nereye gideceği.
- Bahis kilitleme (`locks_at`) ve itiraz penceresi kapanışı için zamanlanmış iş (pg_cron).
- Para dışı admin işlemleri (ban, yetki verme) için ayrı denetim kaydı.
- MIMARI §13'teki rakamlar (başlangıç SP, limitler, itibar eşikleri) bir ayar tablosunda tutulur, sonra kalibre edilir.
