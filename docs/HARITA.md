# KampüsBet — Proje Haritası

Amaç: projeyi **en az bağlam harcayarak** anlamak. Bu dosyayı oku, sonra yalnızca görevin
gerektirdiği bölgeleri aç. Kod dosyalarını baştan sona okuma; bölge dosyası nereye bakacağını söyler.

## Şu an

- **Commit:** yalnızca kullanıcı onay verince, yalnızca yerel (push yok). Adım 5-6 `eea1448`'de; Adım 7, 8 ve 9 çalışma ağacında, commit edilmedi.
- **Son tamamlanan:** Adım 9 — görevler (günlük / haftalık / sezonluk; ilerleme sunucuda kayıtlardan sayılır, ödül dönem başına bir) + kozmetik market (unvan, rozet, çerçeve, isim rengi; SP ve SSP vitrini; kuşanma). Kurallar varsayılan (KARARLAR "Görevler", "Market"). 445 pgTAP, 35 Flutter testi, para eşzamanlılığı 6/6; admin görev ve market sayfaları build temiz. Emülatörde: Görevler ekranında gerçek ilerleme → "Günün tahminini yap" ödülü +20 SP → Market'ten "Mor isim" 350 SP → kuşanıldı, profilde ad mor. Ayrıca sonuç metnindeki eski hata düzeltildi (kazanan tarafa kimse yatırmayınca iade alan kaybedene "Kazandın" yazıyordu).
- **Bulutta deneme verisi:** giriş yapamayan "Test Yetkili" profili (`e2e00000-...0001`), sonuçlanmış resmi ve sosyal deneme bahisleri, bir trivia düellosu, bir günün tahmini; kullanıcının test hesabı `deneme@ogr.ornek.edu.tr` ile doğrulanmış (790 SP, "Mor isim" kuşanılı). Seed'de 5 genel görev, 8 genel ürün.
- **Sıradaki:** Adım 10 — liderlik + istatistik (haftalık snapshot; öne çıkan isabet oranı / en çok kazanan / en iyi seri, "en çok bahis yapan" değil — MIMARI §11). Kuşanılan kozmetikler burada başkalarına görünecek; XP / seviye de bu adımda ele alınabilir ([para](harita/para.md)).
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
| 7 | Sosyal havuz (hakem, itiraz) | Bitti (commit yok) | |
| 8 | Mini oyunlar (trivia düellosu, günün tahmini) | Bitti (commit yok) | |
| 9 | Görevler + market | Bitti (commit yok) | |
| 10 | Liderlik + istatistik | Sırada | |
| 11 | Güvenlik denetimi, hesap silme, KVKK | | |

## Görev → ne okunur

| Görev | Oku | Okuma |
|---|---|---|
| Mobil ekran / akış (Adım 4) | [mobil](harita/mobil.md) + gerekirse ilgili konu bölgesi (kimlik / para / bahis) | migration'lar, testler |
| Admin ekranı (Adım 6) | [admin](harita/admin.md) + ilgili konu bölgesi | migration'lar |
| Yeni SQL tablo / fonksiyon / RLS | [veritabani](harita/veritabani.md) + konu bölgesi + [testler](harita/testler.md) | eski test dosyalarının tamamı |
| Okul, profil, yetki, okul maili (Adım 5) | [kimlik](harita/kimlik.md) | |
| Bakiye, ödül, market, görev (Adım 9) | [para](harita/para.md) | |
| Resmi / sosyal / mini oyun bahisleri (Adım 6-8) | [bahis](harita/bahis.md) | |
| Komut çalıştırma, araç, emülatör, CLI hatası | [ortam](harita/ortam.md) | |
| Test yazma / çalıştırma | [testler](harita/testler.md) | |
| Denenmemiş / eksik / çözülmemiş ne var, kullanıcıdan ne bekleniyor | [acik-isler](harita/acik-isler.md) | |
| Bir kararın gerekçesi | `docs/KARARLAR.md`'de ilgili satırı ara | dosyanın tamamı |
| Ürün vizyonu (ekran haritası, oyunlaştırma) | `docs/MIMARI.md`'nin ilgili bölümü | dosyanın tamamı |

Bölge dosyaları 30-60 satırdır; bir görev genelde 1-3 bölge ister.

## Haritayı güncel tutmak

Bir adım bitince yalnızca: bu dosyadaki "Şu an" ve adım tablosu, değişen bölgenin dosyası.
Yeni karar `KARARLAR.md`'ye tek satır. Geçmiş kaydı tutulmaz; git log yeter.
